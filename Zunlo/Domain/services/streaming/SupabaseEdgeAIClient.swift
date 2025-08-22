//
//  SupabaseEdgeAIClient.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation
import Supabase

// MARK: - SupabaseEdgeAIClient (refined)
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

public struct ResponsesApiTextRequest: Encodable {
    let model: String
    let instructions: String?
    let previous_response_id: String?
    let input: [InputContent]
    let temperature: Double?
    let metadata: [String: String]?
}

private func mapRole(_ role: ChatRole, defaultNonUser: String) -> String {
    switch role {
    case .user: return "user"
    case .assistant, .tool: return defaultNonUser // tool bubbles as assistant context
    case .system: return "system"
    }
}

public protocol EdgeFunctionStreamer {
    func setAuth(token: String)
    func stream(function: String, options: FunctionInvokeOptions) -> AsyncThrowingStream<Data, Error>
    func invoke(function: String, options: FunctionInvokeOptions) async throws -> EmptyResponse
}


public protocol AuthProvider {
    func currentAccessToken() async throws -> String?
}


public final class SupabaseFunctionsStreamer: EdgeFunctionStreamer {
    private let supabase: SupabaseClient
    public init(supabase: SupabaseClient) { self.supabase = supabase }
    public func setAuth(token: String) { supabase.functions.setAuth(token: token) }
    public func stream(function: String, options: FunctionInvokeOptions) -> AsyncThrowingStream<Data, Error> {
        supabase.functions._invokeWithStreamedResponse(function, options: options)
    }
    public func invoke(function: String, options: FunctionInvokeOptions) async throws -> EmptyResponse {
        try await supabase.functions.invoke(function, options: options) as EmptyResponse
    }
}


public struct SupabaseAuthProvider: AuthProvider {
    private let supabase: SupabaseClient
    public init(supabase: SupabaseClient) { self.supabase = supabase }
    public func currentAccessToken() async throws -> String? {
        if let session = try? await supabase.auth.session {
            return session.accessToken
        }
        print("[AI] WARNING: no auth session; chat-msg may 401/500")
        return nil
    }
}

public final class SupabaseEdgeAIClient: AIChatService {
    private let streamer: EdgeFunctionStreamer
    private let auth: AuthProvider

    // Keep a handle for the *current* streaming task so ChatEngine.stop() can cancel
    private var currentTask: Task<Void, Never>? = nil

    // Config
    private let defaultModel: String
    private let defaultTemperature: Double
    private let maxWindowMessages: Int

    public init(
        streamer: EdgeFunctionStreamer,
        auth: AuthProvider,
        model: String = "gpt-4o-mini",
        temperature: Double = 0.2,
        maxWindowMessages: Int = 16
    ) {
        self.streamer = streamer
        self.auth = auth
        self.defaultModel = model
        self.defaultTemperature = temperature
        self.maxWindowMessages = maxWindowMessages
    }
    
    // Convenience init for production
    public convenience init(
        supabase: SupabaseClient,
        model: String = "gpt-4o-mini",
        temperature: Double = 0.2,
        maxWindowMessages: Int = 16
    ) {
        self.init(
            streamer: SupabaseFunctionsStreamer(supabase: supabase),
            auth: SupabaseAuthProvider(supabase: supabase),
            model: model,
            temperature: temperature,
            maxWindowMessages: maxWindowMessages
        )
    }

    public func cancelCurrentGeneration() {
        currentTask?.cancel()
        currentTask = nil
    }

    public func generate(
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
                textContent.append(InputContent(
                    type: "function_call_output",
                    call_id: o.tool_call_id,
                    output: o.output
                ))
            }
        }

        // 4) Windowing (avoid magic 8; make it configurable). Keep more recent messages.
        let tail = Array(textContent.suffix(maxWindowMessages))

        let body = ResponsesApiTextRequest(
            model: defaultModel,
            instructions: systemInstructions,
            previous_response_id: previousResponseId,
            input: tail,
            temperature: defaultTemperature,
            metadata: nil
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
        let token = try? await auth.currentAccessToken()
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
                let token = try? await auth.currentAccessToken()
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
            print("[SSE] event data: \(event.data)")
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

        case name.contains("response.output_item.done"):
            print("[SSE] event data: \(event.data)")
            
        case name.contains("response.required_action"):
            print("[SSE] event data: \(event.data)")
            if let batch = decodeToolBatch(from: event.data) {
                continuation.yield(.toolBatch(batch))
            }

        case name.contains("response.output_text.delta") || name.contains("message.delta"):
            print("[SSE] event data: \(event.data)")
            let text = extractTextDelta(from: event.data)
            if !text.isEmpty { continuation.yield(.delta(replyId: draftId, text: text)) }

        case /*name.contains("response.output_text.done") ||*/ name.contains("response.completed") || name == "completed":
            print("[SSE] event data: \(event.data)")
            sawCompleted = true
            continuation.yield(.completed(replyId: draftId))

        // Optional: suggestions (if your Edge Function emits them)
        case name.contains("response.suggestions") || name.contains("ui.suggestions"):
            print("[SSE] event data: \(event.data)")
            if let chips = extractSuggestions(from: event.data), !chips.isEmpty {
                continuation.yield(.suggestions(chips))
            }

        default:
            // Debug: print(name)
            break
        }
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

//public struct ResponsesApiTextRequest: Encodable {
//    let model: String
//    let instructions: String?
//    let input: [InputContent]
//    let temperature: Double?
//    let metadata: [String: String]?
//}
//
//private func mapRole(_ role: ChatRole, defaultNonUser: String) -> String {
//    switch role {
//    case .user: return "user"
//    case .assistant, .tool: return defaultNonUser // treat tool output as assistant-side context
//    case .system: return ""
//    }
//}
//
//public final class SupabaseEdgeAIClient: AIChatService {
//    private let supabase: SupabaseClient
//    private var cancelBag = [Task<Void, Never>]()
//    private var currentTask: Task<Void, Never>?
//
//    var fn = FnCallAccumulator()
//    
//    public init(supabase: SupabaseClient) {
//        self.supabase = supabase
//    }
//
//    public func cancelCurrentGeneration() {
//        currentTask?.cancel()
//        currentTask = nil
//    }
//
//    public func generate(
//        conversationId: UUID,
//        history: [ChatMessage],
//        output: [ToolOutput],
//        supportsTools: Bool
//    ) throws -> AsyncThrowingStream<AIEvent, Error> {
//        
//        var textContent: [InputContent] = []
//        
//        for (idx, msg) in history.enumerated() {
//            if !output.isEmpty && idx == history.count - 1 {
//                textContent.append(InputContent(
//                    type: "function_call_output",
//                    call_id: output.first!.tool_call_id,
//                    output: output.first!.output
//                ))
//            } else if !msg.rawText.isEmpty {
//                textContent.append(InputContent(
//                    role: mapRole(msg.role, defaultNonUser: "assistant"),
//                    content: msg.rawText
//                ))
//            }
//        }
//        
//        let tail = Array(textContent.suffix(8))
//        
//        let body = ResponsesApiTextRequest(
//            model: "gpt-4o-mini",
//            instructions: nil,
//            input: tail,
//            temperature: 0.2,
//            metadata: nil
//        )
//
//        return AsyncThrowingStream { continuation in
//            // Prepare options (body is Encodable; client sets Content-Type automatically)
//            let opts = FunctionInvokeOptions(
//                headers: ["Accept": "text/event-stream"],
//                body: body
//            )
//
//            // Emit a started/draft id immediately so your VM can create a placeholder
//            let draftId = UUID()
//            continuation.yield(.started(replyId: draftId))
//
//            // Start streaming
//            currentTask = Task { [weak self] in
//                guard let self else { return }
//                await self.runStream(opts: opts, draftId: draftId, continuation: continuation)
//            }
//
//            continuation.onTermination = { _ in
//                self.currentTask?.cancel()
//                self.currentTask = nil
//            }
//        }
//    }
//    
//    public func submitToolOutputs(responseId: String, outputs: [ToolOutput]) async throws {
//        struct Body: Encodable { let response_id: String; let tool_outputs: [ToolOutput] }
//        let b = Body(response_id: responseId, tool_outputs: outputs)
//        _ = try await supabase.functions.invoke(
//            "tool_outputs",
//            options: FunctionInvokeOptions(body: b)
//        ) as EmptyResponse // ignore return, stream will continue
//    }
//    
//    // Make the streaming loop NON-throwing by catching inside.
//    private func runStream(
//        opts: FunctionInvokeOptions,
//        draftId: UUID,
//        continuation: AsyncThrowingStream<AIEvent, Error>.Continuation
//    ) async {
//        do {
//            // If you need auth on Functions:
//            if let session = try? await supabase.auth.session {
//                supabase.functions.setAuth(token: session.accessToken)
//            }
//
//            var responseCreated = false
//            
//            var parser = SSEParser()
//            let bytes = supabase.functions._invokeWithStreamedResponse("chat-msg", options: opts)
//
//            for try await chunk in bytes {
//                for event in parser.feed(chunk) {
//                    let name = event.event ?? ""
//
//                    print("***** SSE event name: \(name)")
//                    switch true {
////                        response.in_progress
////                        response.content_part.added
////                        response.content_part.done
////                        response.output_text.done
////                        response.output_item.done
//                        case name.contains("response.created"):
//                            responseCreated = true
//                            if let rid = extractResponseId(from: event.data) {
//                                fn.responseId = rid
//                                continuation.yield(.responseCreated(responseId: rid))
//                            }
//
//                        case name.contains("response.output_item.added"):
//                            if let (itemId, toolName, callId) = parseFunctionCallAdded(event.data) {
//                                print("[SSE] function_call started:", toolName, "id:", itemId)
//                                fn.startCall(id: itemId, name: toolName, callId: callId)
//                            }
//
//                        case name.contains("response.function_call_arguments.delta"):
//                            if let (itemId, chunk) = parseFunctionCallArgsDelta(event.data) {
//                                print("[SSE] args delta(\(itemId)):", chunk.prefix(120))
//                                fn.appendArgs(id: itemId, chunk: chunk)
//                            }
//
//                        case name.contains("response.function_call_arguments.done"):
//                            if let (itemId, args) = parseFunctionCallArgsDone(event.data),
//                               let call = fn.finishCall(id: itemId, args: args) {
//                                print("[SSE] function_call done for:", itemId)
//                                // Convert to your AIEvent tool batch (single call here)
//                                let req = ToolCallRequest(
//                                    id: itemId,
//                                    callId: call.callId,
//                                    name: call.name,
//                                    argumentsJSON: call.args,
//                                    responseId: fn.responseId ?? "",
//                                    origin: .streamed
//                                )
//                                continuation.yield(.toolBatch([req]))
//                            }
//
//                        case name.contains("response.required_action"):
//                            // Keep your existing path (submit tool_outputs)
//                            if let batch = decodeToolBatch(from: event.data) {
//                                continuation.yield(.toolBatch(batch))
//                            }
//
//                        case name.contains("response.output_text.delta"),
//                             name.contains("message.delta"):
//                            let text = extractTextDelta(from: event.data)
//                            if !text.isEmpty {
//                                continuation.yield(.delta(replyId: draftId, text: text))
//                            }
//
//                        case name.contains("response.completed"), name == "completed":
//                            continuation.yield(.completed(replyId: draftId))
//
//                        default:
//                        print("[SSE] name:", name)
//                    }
//                }
//            }
//
//            if !responseCreated {
//                // Server closed stream without an explicit completed event:
//                continuation.yield(.completed(replyId: draftId))
//            }
//            continuation.finish()
//
//        } catch {
//            if Task.isCancelled {
//                // User tapped Stop; finish quietly.
//                continuation.finish()
//            } else {
//                continuation.finish(throwing: error)
//            }
//        }
//    }
//
//
//    // Helpers to be tolerant to both {"arguments":{...}} and {"arguments":"{...}"}
//    private func extractToolName(from json: String) -> String {
//        (try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])?["name"] as? String ?? "tool"
//    }
//    
//    private func extractToolArgs(from json: String) -> String {
//        if let obj = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] {
//            if let s = obj["arguments"] as? String { return s }
//            if let o = obj["arguments"] { return String(data: (try? JSONSerialization.data(withJSONObject: o)) ?? Data("{}".utf8), encoding: .utf8) ?? "{}" }
//        }
//        return "{}"
//    }
//    
//    private func decodeToolBatch(from json: String) -> [ToolCallRequest]? {
//        guard
//          let obj = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
//          let response = obj["response"] as? [String: Any],
//          let responseId = response["id"] as? String,
//          let ra = obj["required_action"] as? [String: Any],
//          (ra["type"] as? String) == "submit_tool_outputs",
//          let tools = ra["tools"] as? [[String: Any]]
//        else { return nil }
//
//        return tools.compactMap { t -> ToolCallRequest? in
//            guard
//              let id = t["id"] as? String,
//              let name = t["name"] as? String,
//              let callId = t["call_id"] as? String
//            else { return nil }
//            // arguments might be object or string
//            let argsAny = (t["arguments"] as Any)
//            let argsJSON: String = {
//                if let s = argsAny as? String { return s }
//                if JSONSerialization.isValidJSONObject(argsAny),
//                   let d = try? JSONSerialization.data(withJSONObject: argsAny),
//                   let s = String(data: d, encoding: .utf8) { return s }
//                return "{}"
//            }()
//            return ToolCallRequest(
//                id: id,
//                callId: callId,
//                name: name,
//                argumentsJSON: argsJSON,
//                responseId: responseId,
//                origin: .requiredAction
//            )
//        }
//    }
//    
//    private struct ResponseCreatedEnvelope: Decodable {
//        struct Inner: Decodable { let id: String? }
//        let id: String?
//        let response: Inner?
//    }
//    
//    /// Minimal shape covering both `response.created` and `response.required_action`
//    private struct ResponseIdEnvelope: Decodable {
//        struct Inner: Decodable { let id: String? }
//        let id: String?          // some events may put id here
//        let response: Inner?     // Responses API puts it here for created/required_action
//    }
//
//    private func extractResponseId(from json: String) -> String? {
//        guard let data = json.data(using: .utf8) else { return nil }
//
//        // 1) Try Decodable (fast & safe)
//        if let env = try? JSONDecoder().decode(ResponseIdEnvelope.self, from: data) {
//            if let id = env.response?.id ?? env.id { return id }
//        }
//
//        // 2) Fallback: permissive JSON traversal
//        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
//            if let id = obj["id"] as? String { return id }
//            if let resp = obj["response"] as? [String: Any],
//               let id = resp["id"] as? String { return id }
//        }
//        return nil
//    }
//
//    // Handles either:
//    //  • event: "response.output_text.delta" → { ..., "delta": "text chunk", ... }
//    //  • event: "message.delta" → { ..., "delta": { "content": [ { "type":"output_text_delta","text":"..." }, ... ] } }
//    private func extractTextDelta(from json: String) -> String {
//        guard let data = json.data(using: .utf8) else { return "" }
//
//        // A) response.output_text.delta
//        struct OutputTextDeltaEnvelope: Decodable { let delta: String? }
//        if let env = try? JSONDecoder().decode(OutputTextDeltaEnvelope.self, from: data),
//           let s = env.delta, !s.isEmpty {
//            return s
//        }
//
//        // B) message.delta (delta.content[*].text)
//        struct MessageDeltaEnvelope: Decodable {
//            struct Delta: Decodable {
//                struct Content: Decodable { let type: String?; let text: String? }
//                let content: [Content]?
//            }
//            let delta: Delta?
//        }
//        if let env = try? JSONDecoder().decode(MessageDeltaEnvelope.self, from: data) {
//            let joined = (env.delta?.content ?? []).compactMap { $0.text }.joined()
//            if !joined.isEmpty { return joined }
//        }
//
//        // C) Fallback: permissive traversal
//        if let any = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
//            if let s = any["delta"] as? String { return s }
//            if let delta = any["delta"] as? [String: Any] {
//                if let s = delta["text"] as? String { return s }
//                if let content = delta["content"] as? [[String: Any]] {
//                    let joined = content.compactMap { $0["text"] as? String }.joined()
//                    if !joined.isEmpty { return joined }
//                }
//            }
//        }
//
//        return "" // don't append raw JSON if we can't parse
//    }
//    
//    private func parseFunctionCallAdded(_ json: String) -> (itemId: String, name: String, callId: String)? {
//        guard let data = json.data(using: .utf8),
//              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
//
//        // Common shapes:
//        // { ..., "item": {"id":"item_…", "type":"function_call", "name":"getAgenda"} }
//        // {
//        //     "id": "fc_12345xyz",
//        //     "call_id": "call_12345xyz",
//        //     "type": "function_call",
//        //     "name": "get_weather",
//        //     "arguments": "{\"location\":\"Paris, France\"}"
//        // }
//        if let item = obj["item"] as? [String: Any],
//           let type = item["type"] as? String, type == "function_call",
//           let id = item["id"] as? String,
//           let name = item["name"] as? String,
//           let callId = item["call_id"] as? String {
//            return (id, name, callId)
//        }
//
//        // Fallbacks if schema varies slightly
//        if let id = obj["item_id"] as? String,
//           let callId = obj["call_id"] as? String,
//           let name = (obj["name"] as? String) ?? ((obj["function_call"] as? [String: Any])?["name"] as? String) {
//            return (id, name, callId)
//        }
//        return nil
//    }
//
//    private func parseFunctionCallArgsDelta(_ json: String) -> (itemId: String, chunk: String)? {
//        guard let data = json.data(using: .utf8),
//              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
//
//        // Common shapes:
//        // { "item_id":"item_…", "delta":"{\"dateRange\":\"today\""}
//        if let id = (obj["item_id"] as? String) ?? (obj["id"] as? String),
//           let delta = obj["delta"] as? String {
//            return (id, delta)
//        }
//        return nil
//    }
//
//    private func parseFunctionCallArgsDone(_ json: String) -> (itemId: String, args: String)? {
//        // Usually carries { "item_id": "item_…" }
//        guard let data = json.data(using: .utf8),
//              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
////        return (obj["item_id"] as? String) ?? (obj["id"] as? String)
//        
////        {
////          "type": "response.function_call_arguments.done",
////          "item_id": "item-abc",
////          "output_index": 1,
////          "arguments": "{ \"arg\": 123 }",
////          "sequence_number": 1
////        }
//        if let id = (obj["item_id"] as? String) ?? (obj["id"] as? String),
//           let args = obj["arguments"] as? String {
//            return (id, args)
//        }
//        return nil
//    }
//
//}
