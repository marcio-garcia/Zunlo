//
//  SupabaseAIChatClient.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation
import Supabase

// MARK: - SupabaseAIChatClient (refined)
// Goals:
// 1) Integrates cleanly with ChatEngine (actor) from the canvas refactor
// 2) No shared mutable state across streams (localize accumulators)
// 3) Correctly handles multiple tool outputs and system instructions
// 4) Robust SSE parsing (delta, response.created, required_action, streamed function calls)
// 5) Clear cancellation semantics
//
// Assumptions:
// - AIEvent is your existing streaming event enum with cases:
//   .started(UUID), .delta(UUID, String), .toolBatch([ToolCallRequest]), .responseCreated(String), .completed(UUID)
//   (If your labels differ, add a typealias or adapt the call sites.)
// - InputContent is your request content type (role/content or function_call_output)
// - SupabaseClient + FunctionInvokeOptions types come from supabase-swift

import Foundation

struct ChatStructuredResponse: Decodable {
    let displayText: String
    let actions: [String]
}

final class SupabaseAIChatClient: AIChatService {
    private let streamer: EdgeFunctionStreamer
    private let auth: AuthProviding

    // Keep a handle for the *current* streaming task so ChatEngine.stop() can cancel
    private var currentTask: Task<Void, Never>? = nil

    // Config
    private let config: SupabaseAIChatConfig

    public init(
        auth: AuthProviding,
        config: SupabaseAIChatConfig = SupabaseAIChatConfig(),
        streamer: EdgeFunctionStreamer
    ) {
        self.streamer = streamer
        self.auth = auth
        self.config = config
    }
    
    // Convenience init for production
    public convenience init(
        auth: AuthProviding,
        config: SupabaseAIChatConfig = SupabaseAIChatConfig(),
        supabase: SupabaseClient
    ) {
        self.init(
            auth: auth,
            config: config,
            streamer: SupabaseFunctionsStreamer(supabase: supabase)
        )
    }

    public func cancelCurrentGeneration() {
        currentTask?.cancel()
        currentTask = nil
    }

    func generate(
        conversationId: UUID,
        history: [ChatMessage],
        output: [ToolOutput],
        supportsTools: Bool
    ) throws -> AsyncThrowingStream<AIEvent, Error> {

        var previousResponseId: String? = nil
        
        // 1) Build instructions from system messages; keep only latest when multiple
        let systemInstructions: String? = {
            let sys = history.filter { $0.role == .system }.map { $0.rawText }.joined(separator: "\n\n")
            return sys.isEmpty ? nil : sys
        }()

        // 2) Build InputContent window (role/content) WITHOUT system (already in instructions)
        var textContent: [InputContent] = []
        for msg in history where msg.role != .system {
            if !msg.rawText.isEmpty {
                textContent.append(InputContent(
                    role: mapRole(msg.role, defaultNonUser: "assistant"),
                    content: msg.rawText
                ))
            }
        }

        // 3) If we have function call outputs (streamed tool path), append *all* at the end
        if !output.isEmpty {
            for o in output {
                previousResponseId = o.previous_response_id
                let content = InputContent(
                    type: "function_call_output",
                    call_id: o.tool_call_id,
                    output: o.output
                )
                print("function call outputs: \(content)")
                textContent.append(content)
            }
        }

        // 4) Windowing. Keep more recent messages.
        let tail = Array(textContent.suffix(config.maxWindowMessages))

        let body = ResponsesApiTextRequest(
            model: config.model,
            instructions: systemInstructions,
            previous_response_id: previousResponseId,
            input: tail,
            temperature: config.temperature,
            metadata: nil,
            localNowISO: Date.localDateToAI(),
            localTimezone: Calendar.appDefault.timeZone.identifier,
            response_type: config.responseType
        )

        return AsyncThrowingStream { continuation in
            // Prepare options
            let opts = FunctionInvokeOptions(
                headers: ["Accept": "text/event-stream", "Content-Type": "application/json"],
                body: body
            )

            // Emit a started/draft id immediately so the engine/VM can create a placeholder
            let draftId = UUID()
            continuation.yield(.started(replyId: draftId))

            // Local (per-stream) accumulators to avoid cross-stream contamination
            var fn = FnCallAccumulator()

            // Start streaming in a cancellable task
            currentTask = Task { [weak self] in
                guard let self else { return }
                await self.runStream(opts: opts, draftId: draftId, fn: &fn, continuation: continuation)
            }

            // Ensure cancellation tears down the task and finishes the stream
            continuation.onTermination = { [weak self] _ in
                self?.currentTask?.cancel()
                self?.currentTask = nil
            }
        }
    }

    public func submitToolOutputs(responseId: String, outputs: [ToolOutput]) async throws {
        struct Body: Encodable { let response_id: String; let tool_outputs: [ToolOutput] }
        let b = Body(response_id: responseId, tool_outputs: outputs)
        
        // Ensure auth header is (re)applied
        let token = await auth.accessToken
        if let token = token { streamer.setAuth(token: token) }
        
        _ = try await streamer.invoke(
            function: "tool_outputs",
            options: FunctionInvokeOptions(body: b))
    }

    // MARK: - Streaming

    private func runStream(
        opts: FunctionInvokeOptions,
        draftId: UUID,
        fn: inout FnCallAccumulator,
        continuation: AsyncThrowingStream<AIEvent, Error>.Continuation
    ) async {
        await withTaskCancellationHandler(operation: {
            do {
                // Attach auth for Functions if available
                let token = await auth.accessToken
                if let token = token { streamer.setAuth(token: token) }

                var sawCompleted = false
                var parser = SSEParser()
                let bytes = streamer.stream(function: "chat-msg", options: opts)

                for try await chunk in bytes {
                    for event in parser.feed(chunk) {
                        guard !Task.isCancelled else { break }
                        handleEvent(
                            event,
                            draftId: draftId,
                            fn: &fn,
                            continuation: continuation,
                            sawCompleted: &sawCompleted
                        )
                    }
                }

                if !sawCompleted {
                    // If the server closed without sending completed, emit one so the engine can finalize
                    continuation.yield(.completed(replyId: draftId))
                }
                continuation.finish()
            } catch {
                if Task.isCancelled {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: error)
                }
            }
        }, onCancel: {
            // Ensure the continuation ends promptly on cancellation
            continuation.finish()
        })
    }

    private func handleEvent(
        _ event: SSEEvent,
        draftId: UUID,
        fn: inout FnCallAccumulator,
        continuation: AsyncThrowingStream<AIEvent, Error>.Continuation,
        sawCompleted: inout Bool
    ) {
        let name = event.event ?? ""

        switch true {
        case name.contains("response.created"):
            print("[SSE] event data: \(event.data.prefix(30))")
            if let rid = extractResponseId(from: event.data) {
                fn.responseId = rid
                continuation.yield(.responseCreated(responseId: rid))
            }

        case name.contains("response.output_item.added"):
            print("[SSE] event data: \(event.data)")
            if let (itemId, toolName, callId) = parseFunctionCallAdded(event.data) {
                fn.startCall(id: itemId, name: toolName, callId: callId)
            }

        case name.contains("response.function_call_arguments.delta"):
            print("[SSE] event data: \(event.data)")
            if let (itemId, chunk) = parseFunctionCallArgsDelta(event.data) {
                fn.appendArgs(id: itemId, chunk: chunk)
            }

        case name.contains("response.function_call_arguments.done"):
            print("[SSE] event data: \(event.data)")
            if let (itemId, args) = parseFunctionCallArgsDone(event.data),
               let call = fn.finishCall(id: itemId, args: args) {
                let req = ToolCallRequest(
                    itemId: itemId,
                    callId: call.callId,
                    name: call.name,
                    argumentsJSON: call.args,
                    responseId: fn.responseId ?? "",
                    origin: .streamed
                )
                continuation.yield(.toolBatch([req]))
            }

        case name.contains("response.required_action"):
            print("[SSE] event data: \(event.data)")
            if let batch = decodeToolBatch(from: event.data) {
                continuation.yield(.toolBatch(batch))
            }

        case name.contains("response.output_text.delta") || name.contains("message.delta"):
//            print("[SSE] event data: \(event.data)")
            print("[SSE] event data: \(event.data.prefix(40))")
            switch config.responseType {
            case .plain, .tools:
                let text = extractTextDelta(from: event.data)
                if !text.isEmpty { continuation.yield(.delta(replyId: draftId, text: text)) }
            case .structured:
                break
            }

        case name.contains("response.output_text.done"):
            print("[SSE] event data: \(event.data)")

        case name.contains("response.output_item.done"):
            print("[SSE] event data: \(event.data)")
            if case .structured = config.responseType,
               let outputItemText = OpenAIDataParser().parseOutputTextDone(event.data),
               let structured = parseStructuredResponse(outputItemText) {
                
                continuation.yield(.delta(replyId: draftId, text: structured.displayText))
                
                // TODO: Handle actions if any
                // handleActions(structured.actions)
            }

        // Optional: suggestions (if your Edge Function emits them)
        case name.contains("response.suggestions") || name.contains("ui.suggestions"):
            print("[SSE] event data: \(event.data)")
            if let chips = extractSuggestions(from: event.data), !chips.isEmpty {
                continuation.yield(.suggestions(chips))
            }
            
        case name.contains("response.completed") || name == "completed":
//            print("[SSE] event data: \(event.data)")
            print("[SSE] event data: \(event.data.prefix(40))")
            sawCompleted = true
            continuation.yield(.completed(replyId: draftId))

        default:
            print(name)
            break
        }
    }
    
    private func mapRole(_ role: ChatRole, defaultNonUser: String) -> String {
        switch role {
        case .user: return "user"
        case .assistant, .tool: return defaultNonUser // tool bubbles as assistant context
        case .system: return "system"
        }
    }
    
    private func parseStructuredResponse(_ json: String) -> ChatStructuredResponse? {
        guard
            let data = json.data(using: .utf8),
            let obj = try? JSONDecoder().decode(ChatStructuredResponse.self, from: data)
        else { return nil }
        
        return obj
    }
    
    // MARK: - Parsing helpers (same spirit as your original; tolerant to schema variants)

    private func extractResponseId(from json: String) -> String? {
        guard let data = json.data(using: .utf8) else { return nil }
        struct Envelope: Decodable { struct Inner: Decodable { let id: String? }; let id: String?; let response: Inner? }
        if let env = try? JSONDecoder().decode(Envelope.self, from: data) { return env.response?.id ?? env.id }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return (obj["id"] as? String) ?? ((obj["response"] as? [String: Any])?["id"] as? String)
        }
        return nil
    }

    private func extractTextDelta(from json: String) -> String {
        guard let data = json.data(using: .utf8) else { return "" }
        struct A: Decodable { let delta: String? }
        if let a = try? JSONDecoder().decode(A.self, from: data), let s = a.delta, !s.isEmpty { return s }
        struct B: Decodable { struct D: Decodable { struct C: Decodable { let type: String?; let text: String? }; let content: [C]? }; let delta: D? }
        if let b = try? JSONDecoder().decode(B.self, from: data) { return (b.delta?.content ?? []).compactMap { $0.text }.joined() }
        if let any = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let s = any["delta"] as? String { return s }
            if let d = any["delta"] as? [String: Any] {
                if let s = d["text"] as? String { return s }
                if let content = d["content"] as? [[String: Any]] { return content.compactMap { $0["text"] as? String }.joined() }
            }
        }
        return ""
    }

    private func extractSuggestions(from json: String) -> [String]? {
        guard let data = json.data(using: .utf8) else { return nil }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let chips = obj["suggestions"] as? [String] { return chips }
            if let chips = obj["chips"] as? [String] { return chips }
            if let ui = obj["ui"] as? [String: Any], let chips = ui["suggestions"] as? [String] { return chips }
        }
        return nil
    }

    private func decodeToolBatch(from json: String) -> [ToolCallRequest]? {
        guard
            let obj = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
            let response = obj["response"] as? [String: Any],
            let responseId = response["id"] as? String,
            let ra = obj["required_action"] as? [String: Any],
            (ra["type"] as? String) == "submit_tool_outputs",
            let tools = ra["tools"] as? [[String: Any]]
        else { return nil }

        return tools.compactMap { t -> ToolCallRequest? in
            guard let id = t["id"] as? String, let name = t["name"] as? String, let callId = t["call_id"] as? String else { return nil }
            let argsAny = t["arguments"] as Any
            let argsJSON: String = {
                if let s = argsAny as? String { return s }
                if JSONSerialization.isValidJSONObject(argsAny),
                   let d = try? JSONSerialization.data(withJSONObject: argsAny),
                   let s = String(data: d, encoding: .utf8) { return s }
                return "{}"
            }()
            return ToolCallRequest(itemId: id, callId: callId, name: name, argumentsJSON: argsJSON, responseId: responseId, origin: .requiredAction)
        }
    }

    private func parseFunctionCallAdded(_ json: String) -> (itemId: String, name: String, callId: String)? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let item = obj["item"] as? [String: Any],
           let type = item["type"] as? String, type == "function_call",
           let id = item["id"] as? String,
           let name = item["name"] as? String,
           let callId = item["call_id"] as? String { return (id, name, callId) }
        if let id = obj["item_id"] as? String,
           let callId = obj["call_id"] as? String,
           let name = (obj["name"] as? String) ?? ((obj["function_call"] as? [String: Any])?["name"] as? String) { return (id, name, callId) }
        return nil
    }

    private func parseFunctionCallArgsDelta(_ json: String) -> (itemId: String, chunk: String)? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let id = (obj["item_id"] as? String) ?? (obj["id"] as? String),
           let delta = obj["delta"] as? String { return (id, delta) }
        return nil
    }

    private func parseFunctionCallArgsDone(_ json: String) -> (itemId: String, args: String)? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let id = (obj["item_id"] as? String) ?? (obj["id"] as? String),
           let args = obj["arguments"] as? String { return (id, args) }
        return nil
    }
}

class OpenAIDataParser {
    
    func parseOutputTextDone(_ json: String) -> String? {
        guard
            let data = json.data(using: .utf8),
            let outputItem = try? JSONDecoder().decode(OpenAIOutputItem.self, from: data)
        else { return nil }
        
        for content in outputItem.item.content {
            return content.text
        }
        
        return nil
    }
}
