//
//  SupabaseEdgeAIClient.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation
import Supabase

public final class SupabaseEdgeAIClient: AIChatService {
    private let supabase: SupabaseClient
    private var cancelBag = [Task<Void, Never>]()
    private var currentTask: Task<Void, Never>?

    var fn = FnCallAccumulator()
    
    public init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    public func cancelCurrentGeneration() {
        currentTask?.cancel()
        currentTask = nil
    }

    public func generate(
        conversationId: UUID,
        history: [ChatMessage],
        userInput: String,
        attachments: [ChatAttachment],
        supportsTools: Bool
    ) -> AsyncThrowingStream<AIEvent, Error> {

        struct Msg: Codable { let role: String; let content: String }
        struct Body: Codable {
            let model: String
            let input: [Msg]
            // Add tools/tool_choice later (Phase 4)
        }

        let inputMsgs = history.map { Msg(role: $0.role.rawValue, content: $0.text) }
        let body = Body(model: "gpt-5-mini", input: inputMsgs)

        return AsyncThrowingStream { continuation in
            // Prepare options (body is Encodable; client sets Content-Type automatically)
            let opts = FunctionInvokeOptions(
                headers: ["Accept": "text/event-stream"],
                body: body
            )

            // Emit a started/draft id immediately so your VM can create a placeholder
            let draftId = UUID()
            continuation.yield(.started(replyId: draftId))

            // Start streaming
            currentTask = Task { [weak self] in
                guard let self else { return }
                await self.runStream(opts: opts, draftId: draftId, continuation: continuation)
            }

            continuation.onTermination = { _ in
                self.currentTask?.cancel()
                self.currentTask = nil
            }
        }
    }
    
    public func submitToolOutputs(responseId: String, outputs: [ToolOutput]) async throws {
        struct Body: Encodable { let response_id: String; let tool_outputs: [ToolOutput] }
        let b = Body(response_id: responseId, tool_outputs: outputs)
        _ = try await supabase.functions.invoke(
            "tool_outputs",
            options: FunctionInvokeOptions(body: b)
        ) as EmptyResponse // ignore return, stream will continue
    }
    
    // Make the streaming loop NON-throwing by catching inside.
    private func runStream(
        opts: FunctionInvokeOptions,
        draftId: UUID,
        continuation: AsyncThrowingStream<AIEvent, Error>.Continuation
    ) async {
        do {
            // If you need auth on Functions:
            if let session = try? await supabase.auth.session {
                supabase.functions.setAuth(token: session.accessToken)
            }

            var parser = SSEParser()
            let bytes = supabase.functions._invokeWithStreamedResponse("chat-msg", options: opts)

            for try await chunk in bytes {
                for event in parser.feed(chunk) {
                    let name = event.event ?? ""

                    print("***** SSE event name: \(name)")
                    switch true {
                        case name.contains("response.created"):
                            if let rid = extractResponseId(from: event.data) {
                                fn.responseId = rid
                                continuation.yield(.responseCreated(responseId: rid))
                            }

                        case name.contains("response.output_item.added"):
                            if let (itemId, toolName) = parseFunctionCallAdded(event.data) {
                                print("[SSE] function_call started:", toolName, "id:", itemId)
                                fn.startCall(id: itemId, name: toolName)
                                // (optional) debug: print("[SSE] function_call started:", toolName, "id:", itemId)
                            }

                        case name.contains("response.function_call_arguments.delta"):
                            if let (itemId, chunk) = parseFunctionCallArgsDelta(event.data) {
                                print("[SSE] args delta(\(itemId)):", chunk.prefix(120))
                                fn.appendArgs(id: itemId, chunk: chunk)
                            }

                        case name.contains("response.function_call_arguments.done"):
                            if let itemId = parseFunctionCallArgsDone(event.data),
                               let call = fn.finishCall(id: itemId) {
                                print("[SSE] function_call done for:", itemId)
                                // Convert to your AIEvent tool batch (single call here)
                                let req = ToolCallRequest(
                                    id: itemId,
                                    name: call.name,
                                    argumentsJSON: call.argsJSON,
                                    responseId: fn.responseId ?? "",
                                    origin: .streamed
                                )
                                continuation.yield(.toolBatch([req]))
                            }

                        case name.contains("response.required_action"):
                            // Keep your existing path (submit tool_outputs)
                            if let batch = decodeToolBatch(from: event.data) {
                                continuation.yield(.toolBatch(batch))
                            }

                        case name.contains("response.output_text.delta"),
                             name.contains("message.delta"):
                            let text = extractTextDelta(from: event.data)
                            if !text.isEmpty {
                                continuation.yield(.delta(replyId: draftId, text: text))
                            }

                        case name.contains("response.completed"), name == "completed":
                            continuation.yield(.completed(replyId: draftId))

                        default:
                            break
                        }
                }
            }

            // Server closed stream without an explicit completed event:
            continuation.yield(.completed(replyId: draftId))
            continuation.finish()

        } catch {
            if Task.isCancelled {
                // User tapped Stop; finish quietly.
                continuation.finish()
            } else {
                continuation.finish(throwing: error)
            }
        }
    }


    // Helpers to be tolerant to both {"arguments":{...}} and {"arguments":"{...}"}
    private func extractToolName(from json: String) -> String {
        (try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])?["name"] as? String ?? "tool"
    }
    
    private func extractToolArgs(from json: String) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] {
            if let s = obj["arguments"] as? String { return s }
            if let o = obj["arguments"] { return String(data: (try? JSONSerialization.data(withJSONObject: o)) ?? Data("{}".utf8), encoding: .utf8) ?? "{}" }
        }
        return "{}"
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

        return tools.compactMap { t in
            guard
              let id = t["id"] as? String,
              let name = t["name"] as? String
            else { return nil }
            // arguments might be object or string
            let argsAny = (t["arguments"] as Any)
            let argsJSON: String = {
                if let s = argsAny as? String { return s }
                if JSONSerialization.isValidJSONObject(argsAny),
                   let d = try? JSONSerialization.data(withJSONObject: argsAny),
                   let s = String(data: d, encoding: .utf8) { return s }
                return "{}"
            }()
            return ToolCallRequest(
                id: id,
                name: name,
                argumentsJSON: argsJSON,
                responseId: responseId,
                origin: .requiredAction
            )
        }
    }
    
    private struct ResponseCreatedEnvelope: Decodable {
        struct Inner: Decodable { let id: String? }
        let id: String?
        let response: Inner?
    }
    
    /// Minimal shape covering both `response.created` and `response.required_action`
    private struct ResponseIdEnvelope: Decodable {
        struct Inner: Decodable { let id: String? }
        let id: String?          // some events may put id here
        let response: Inner?     // Responses API puts it here for created/required_action
    }

    private func extractResponseId(from json: String) -> String? {
        guard let data = json.data(using: .utf8) else { return nil }

        // 1) Try Decodable (fast & safe)
        if let env = try? JSONDecoder().decode(ResponseIdEnvelope.self, from: data) {
            if let id = env.response?.id ?? env.id { return id }
        }

        // 2) Fallback: permissive JSON traversal
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let id = obj["id"] as? String { return id }
            if let resp = obj["response"] as? [String: Any],
               let id = resp["id"] as? String { return id }
        }
        return nil
    }

    // Handles either:
    //  • event: "response.output_text.delta" → { ..., "delta": "text chunk", ... }
    //  • event: "message.delta" → { ..., "delta": { "content": [ { "type":"output_text_delta","text":"..." }, ... ] } }
    private func extractTextDelta(from json: String) -> String {
        guard let data = json.data(using: .utf8) else { return "" }

        // A) response.output_text.delta
        struct OutputTextDeltaEnvelope: Decodable { let delta: String? }
        if let env = try? JSONDecoder().decode(OutputTextDeltaEnvelope.self, from: data),
           let s = env.delta, !s.isEmpty {
            return s
        }

        // B) message.delta (delta.content[*].text)
        struct MessageDeltaEnvelope: Decodable {
            struct Delta: Decodable {
                struct Content: Decodable { let type: String?; let text: String? }
                let content: [Content]?
            }
            let delta: Delta?
        }
        if let env = try? JSONDecoder().decode(MessageDeltaEnvelope.self, from: data) {
            let joined = (env.delta?.content ?? []).compactMap { $0.text }.joined()
            if !joined.isEmpty { return joined }
        }

        // C) Fallback: permissive traversal
        if let any = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let s = any["delta"] as? String { return s }
            if let delta = any["delta"] as? [String: Any] {
                if let s = delta["text"] as? String { return s }
                if let content = delta["content"] as? [[String: Any]] {
                    let joined = content.compactMap { $0["text"] as? String }.joined()
                    if !joined.isEmpty { return joined }
                }
            }
        }

        return "" // don't append raw JSON if we can't parse
    }
    
    private func parseFunctionCallAdded(_ json: String) -> (itemId: String, name: String)? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        // Common shapes:
        // { ..., "item": {"id":"item_…", "type":"function_call", "name":"getAgenda"} }
        if let item = obj["item"] as? [String: Any],
           let type = item["type"] as? String, type == "function_call",
           let id = item["id"] as? String,
           let name = item["name"] as? String {
            return (id, name)
        }

        // Fallbacks if schema varies slightly
        if let id = obj["item_id"] as? String,
           let name = (obj["name"] as? String) ?? ((obj["function_call"] as? [String: Any])?["name"] as? String) {
            return (id, name)
        }
        return nil
    }

    private func parseFunctionCallArgsDelta(_ json: String) -> (itemId: String, chunk: String)? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        // Common shapes:
        // { "item_id":"item_…", "delta":"{\"dateRange\":\"today\""}
        if let id = (obj["item_id"] as? String) ?? (obj["id"] as? String),
           let delta = obj["delta"] as? String {
            return (id, delta)
        }
        return nil
    }

    private func parseFunctionCallArgsDone(_ json: String) -> String? {
        // Usually carries { "item_id": "item_…" }
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (obj["item_id"] as? String) ?? (obj["id"] as? String)
    }

}
