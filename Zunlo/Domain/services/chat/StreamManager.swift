//
//  StreamManager.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/22/25.
//

import Foundation
import SmartParseKit
import LoggingKit

/// Handles AI streaming and remote tool calls
actor StreamManager {
    private let ai: AIChatService
    private let persistence: MessagePersistence
    private let localTools: Tools
    private let conversationId: UUID

    private var pendingStreamedToolOutputs: [ToolOutput] = []
    private var emittedText = Set<UUID>()
    private var toolingAssistantId: UUID?
    private var mdDetectors: [UUID: MarkdownFormatDetector] = [:]

    init(ai: AIChatService, persistence: MessagePersistence, localTools: Tools, conversationId: UUID) {
        self.ai = ai
        self.persistence = persistence
        self.localTools = localTools
        self.conversationId = conversationId
    }

    /// Start streaming with AI service (remote path)
    func startStream(history: [ChatMessage], userMessage: ChatMessage, output: [ToolOutput] = []) -> AsyncStream<ChatEngineEvent> {
        return AsyncStream<ChatEngineEvent> { continuation in
            Task {
                do {
                    try await persistence.upsert(userMessage)
                    continuation.yield(.messageAppended(userMessage))

                    let baseHistory = history + [userMessage]
                    try await consumeStream(history: baseHistory, outputs: output, continuation: continuation)

                    // Handle pending tool outputs from streaming
                    while true {
                        let outs = drainPendingStreamedToolOutputs()
                        if outs.isEmpty { break }
                        let hist = try await persistence.loadMessages(conversationId: conversationId, limit: nil)
                        try await consumeStream(history: hist, outputs: outs, continuation: continuation)
                    }
                } catch {
                    log("StreamManager error: \(error)")
                }
                continuation.finish()
            }
        }
    }

    func cancelCurrentGeneration() {
        ai.cancelCurrentGeneration()
    }

    private func consumeStream(history: [ChatMessage], outputs: [ToolOutput], continuation: AsyncStream<ChatEngineEvent>.Continuation) async throws {
        let stream = try ai.generate(conversationId: conversationId, history: history, output: outputs, supportsTools: true)
        for try await event in stream {
            try Task.checkCancellation()
            await handleAIEvent(event, continuation: continuation)
        }
    }

    private func handleAIEvent(_ event: AIEvent, continuation: AsyncStream<ChatEngineEvent>.Continuation) async {
        switch event {
        case .started(let id):
            if let prior = toolingAssistantId, !emittedText.contains(prior) {
                try? await persistence.delete(messageId: prior)
                continuation.yield(.messageStatusUpdated(messageId: prior, status: .deleted, error: nil))
                toolingAssistantId = nil
            }

            let assistant = createAssistantMessage(conversationId: conversationId, id: id, rawText: "", status: .streaming, actions: [])
            mdDetectors[id] = MarkdownFormatDetector()

            try? await persistence.upsert(assistant)
            continuation.yield(.messageAppended(assistant))

        case .delta(let id, let delta):
            continuation.yield(.messageDelta(messageId: id, delta: delta))
            emittedText.insert(id)
            await persistence.bufferDelta(id: id, delta: delta)

            if let det = mdDetectors[id], det.feed(delta) {
                mdDetectors[id] = det
                continuation.yield(.messageFormatUpdated(messageId: id, format: .markdown))
                try? await persistence.setFormat(messageId: id, format: .markdown)
            }

        case .toolCall(let responseId, let name, let argsJSON):
            await runSingleTool(name: name, argsJSON: argsJSON, continuation: continuation)

        case .toolBatch(let calls):
            if let a = getCurrentAssistantId(), !emittedText.contains(a) {
                let toolNames = calls.map { $0.name }.joined(separator: ", ")
                let awaitingText = EnvConfig.shared.environment == .dev ? "⏳ Using \(toolNames)…" : "⏳ Thinking..."
                continuation.yield(.messageDelta(messageId: a, delta: awaitingText))
                toolingAssistantId = a
            }
            await runToolBatch(calls, continuation: continuation)

        case .suggestions(let chips):
            continuation.yield(.suggestions(chips))

        case .completed(let id):
            if toolingAssistantId == id && !emittedText.contains(id) {
                continuation.yield(.completed(messageId: id))
                return
            }

            if let det = mdDetectors[id], det.decided {
                try? await persistence.setFormat(messageId: id, format: .markdown)
                continuation.yield(.messageFormatUpdated(messageId: id, format: .markdown))
            }

            await persistence.flushDeltaNow(id)
            try? await persistence.setStatus(messageId: id, status: .sent, error: nil)
            continuation.yield(.messageStatusUpdated(messageId: id, status: .sent, error: nil))
            continuation.yield(.completed(messageId: id))

            mdDetectors[id] = nil
            emittedText.remove(id)
            if toolingAssistantId == id { toolingAssistantId = nil }

        case .responseCreated(let rid):
            continuation.yield(.responseCreated(rid))
        }
    }

    private func getCurrentAssistantId() -> UUID? {
        // TODO: Need state management for current assistant
        return nil
    }

    private func drainPendingStreamedToolOutputs() -> [ToolOutput] {
        let outs = pendingStreamedToolOutputs
        pendingStreamedToolOutputs.removeAll()
        return outs
    }

    private func runSingleTool(name: String, argsJSON: String, continuation: AsyncStream<ChatEngineEvent>.Continuation) async {
        // Bridge AI tool calls to local tools
        let toolMsg = ChatMessage(
            conversationId: conversationId,
            role: .tool,
            plain: "AI tool calling bridged to local tools: \(name)",
            createdAt: Date(),
            status: .sent
        )
        try? await persistence.upsert(toolMsg)
        continuation.yield(.messageAppended(toolMsg))
    }

    private func runToolBatch(_ calls: [ToolCallRequest], continuation: AsyncStream<ChatEngineEvent>.Continuation) async {
        // Bridge AI tool batch calls to local tools
        for c in calls {
            let toolMsg = ChatMessage(
                conversationId: conversationId,
                role: .tool,
                plain: "AI tool batch bridged to local tools: \(c.name)",
                createdAt: Date(),
                status: .sent
            )
            try? await persistence.upsert(toolMsg)
            continuation.yield(.messageAppended(toolMsg))
        }
    }

    private func createAssistantMessage(conversationId: UUID, id: UUID? = nil, rawText: String? = nil, richText: AttributedString? = nil, status: ChatMessageStatus, actions: [ChatMessageActionAlternative]) -> ChatMessage {
        if let rich = richText {
            return ChatMessage(id: id ?? UUID(), conversationId: conversationId, role: .assistant, attributed: rich, createdAt: Date(), status: status, actions: actions)
        } else {
            return ChatMessage(id: id ?? UUID(), conversationId: conversationId, role: .assistant, plain: rawText ?? "", createdAt: Date(), status: status, actions: actions)
        }
    }
}