//
//  EdgeAIClient.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

// EdgeAIClient.swift
import Foundation

public final class EdgeAIClient: AIChatService {
    private let baseURL: URL
    private let authHeaderProvider: () -> String?
    private var currentTask: URLSessionDataTask?

    public init(baseURL: URL, authHeaderProvider: @escaping () -> String?) {
        self.baseURL = baseURL
        self.authHeaderProvider = authHeaderProvider
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

        // Minimal body the Edge Function forwards to OpenAI Responses API.
        struct Msg: Codable { let role: String; let content: String }
        struct Body: Codable {
            let model: String
            let input: [Msg]
            // You can add tools/tool_choice here in Phase 4.
        }

        let msgs: [Msg] = history.map { m in
            Msg(role: m.role.rawValue, content: m.text)
        } + [ Msg(role: "user", content: userInput) ]

        let body = Body(model: "gpt-5-mini", input: msgs)

        var req = URLRequest(url: baseURL.appendingPathComponent("/functions/v1/chat"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let auth = authHeaderProvider() { req.setValue(auth, forHTTPHeaderField: "Authorization") }
        req.httpBody = try? JSONEncoder().encode(body)

        return AsyncThrowingStream { continuation in
            let delegate = StreamingDelegate(
                onChunk: { chunk in
                    // Parse SSE packets split by \n\n
                    for event in SSEParser.feed(chunk: chunk) {
                        // OpenAI Responses often uses names like:
                        // "response.output_text.delta", "response.tool_call", "response.completed", etc.
                        let name = event.event ?? ""
                        let data = event.data

                        if name.contains("output_text.delta") || name.contains("message.delta") {
                            continuation.yield(.delta(replyId: self.ensureStarted(continuation: continuation), text: data))
                        } else if name.contains("tool_call") {
                            continuation.yield(.toolCall(name: Self.toolName(from: data), argumentsJSON: Self.toolArgs(from: data)))
                        } else if name.contains("suggestions") {
                            if let chips = try? JSONDecoder().decode([String].self, from: Data(data.utf8)) {
                                continuation.yield(.suggestions(chips))
                            }
                        } else if name.contains("response.completed") || name.contains("completed") {
                            continuation.yield(.completed(replyId: self.ensureStarted(continuation: continuation)))
                        }
                    }
                },
                onFinish: { error in
                    if let error { continuation.finish(throwing: error) }
                    else { continuation.finish() }
                }
            )

            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.dataTask(with: req)
            self.currentTask = task
            // Emit .started with a stable draft id
            self._startedId = UUID()
            continuation.yield(.started(replyId: self._startedId!))
            task.resume()

            continuation.onTermination = { _ in
                task.cancel()
                session.invalidateAndCancel()
                self.currentTask = nil
            }
        }
    }
    
    public func submitToolOutputs(responseId: String, outputs: [ToolOutput]) async throws {
        
    }

    // MARK: - helpers

    private var _startedId: UUID?
    private func ensureStarted(continuation: AsyncThrowingStream<AIEvent, Error>.Continuation) -> UUID {
        if let id = _startedId { return id }
        let id = UUID()
        _startedId = id
        continuation.yield(.started(replyId: id))
        return id
    }

    // Extract tool name/args from model JSON payloads (robust to formats)
    private static func toolName(from json: String) -> String {
        (try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])?["name"] as? String ?? "tool"
    }
    private static func toolArgs(from json: String) -> String {
        // allow either raw object or stringified JSON under "arguments"
        if let obj = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] {
            if let s = obj["arguments"] as? String { return s }
            if let o = obj["arguments"] { return String(data: try! JSONSerialization.data(withJSONObject: o), encoding: .utf8) ?? "{}" }
        }
        return json
    }
    
    // --- tiny SSE helpers (same idea as earlier) ---

    private final class StreamingDelegate: NSObject, URLSessionDataDelegate {
        let onChunk: (Data) -> Void
        let onFinish: (Error?) -> Void
        init(onChunk: @escaping (Data) -> Void, onFinish: @escaping (Error?) -> Void) {
            self.onChunk = onChunk; self.onFinish = onFinish
        }
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) { onChunk(data) }
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) { onFinish(error) }
    }

    private struct SSEEvent { let event: String?; let data: String }
    private enum SSEParser {
        // Splits incoming bytes into SSEEvent(s). Very tolerant.
        static var buffer = Data()
        static func feed(chunk: Data) -> [SSEEvent] {
            buffer.append(chunk)
            var out: [SSEEvent] = []
            while let range = buffer.range(of: Data("\n\n".utf8)) {
                let packet = buffer.subdata(in: 0..<range.lowerBound)
                buffer.removeSubrange(0..<range.upperBound)
                if let s = String(data: packet, encoding: .utf8) {
                    var ev: String?
                    var data = ""
                    for line in s.split(separator: "\n", omittingEmptySubsequences: false) {
                        if line.hasPrefix("event:") { ev = line.dropFirst(6).trimmingCharacters(in: .whitespaces) }
                        else if line.hasPrefix("data:") { data += line.dropFirst(5).trimmingCharacters(in: .whitespaces) }
                    }
                    if !data.isEmpty { out.append(SSEEvent(event: ev, data: data)) }
                }
            }
            return out
        }
    }
}
