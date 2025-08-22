//
//  ChatEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/21/25.
//

// MARK: - ChatEngine Refactor
// Two-actor design:
// 1) ChatEngine (actor) orchestrates streaming, tool calls, persistence, debounced delta flush, and state machine.
// 2) ChatViewModel (@MainActor) focuses on UI state, sectioning, and reacting to engine events.
//
// Notes:
// - This file assumes your existing domain types (ChatMessage, ChatRepository, AIChatService,
//   AIToolRouter, ToolCallRequest, ToolOutput, AIToolEnvelope, ChatInsert, etc.).
// - Replace or adapt initializers/fields to your real models if they differ slightly.

import Foundation
import SwiftUI

// MARK: - Engine Events & State

public enum ChatStreamState: Equatable {
    case idle
    case streaming(assistantId: UUID)
    case awaitingTools(responseId: String, assistantId: UUID?)
    case failed(String)
}

public enum ChatEngineEvent {
    case messageAppended(ChatMessage)                 // new message persisted/emitted (user/assistant/tool)
    case messageDelta(messageId: UUID, delta: String) // assistant token delta
    case messageStatusUpdated(messageId: UUID, status: ChatMessageStatus, error: String?)
    case suggestions([String])
    case responseCreated(String)
    case stateChanged(ChatStreamState)
    case completed(messageId: UUID)
}

// MARK: - ChatEngine (orchestrates streaming/tooling/persistence)

public actor ChatEngine {
    public let conversationId: UUID
    private let ai: AIChatService
    private let tools: ToolRouter
    private let repo: ChatRepository

    private(set) var state: ChatStreamState = .idle
    private var currentStreamTask: Task<Void, Never>? = nil

    // Debounced delta buffers per assistant message
    private var deltaBuffers: [UUID: String] = [:]
    private var deltaFlushTasks: [UUID: Task<Void, Never>] = [:]
    private let deltaFlushNs: UInt64 = 150_000_000 // 150ms

    private var pendingStreamedToolOutputs: [ToolOutput] = []
    
    public init(conversationId: UUID, ai: AIChatService, tools: ToolRouter, repo: ChatRepository) {
        self.conversationId = conversationId
        self.ai = ai
        self.tools = tools
        self.repo = repo
    }

    // Load history via repo actor
    public func loadHistory(limit: Int? = 200) async throws -> [ChatMessage] {
        try await repo.loadMessages(conversationId: conversationId, limit: limit)
    }

    // Start a new turn: persists the user message, then streams the assistant
    public func startStream(history: [ChatMessage], userMessage: ChatMessage, output: [ToolOutput] = []) -> AsyncStream<ChatEngineEvent> {
        cancelCurrentStreamIfAny()

        return AsyncStream<ChatEngineEvent> { continuation in
            // spawn the stream task ON the actor
            currentStreamTask = Task { [weak self] in
                guard let self else { return }
                await self.runStreamChain(history: history,
                                          userMessage: userMessage,
                                          continuation: continuation)
            }

            // tear down ON the actor
            continuation.onTermination = { [weak self] _ in
                Task { await self?.cancelCurrentStreamTask() }
            }
        }
    }

    public func stop() async {
        cancelCurrentStreamIfAny()
        // Best-effort: mark last streaming assistant as sent (if we can infer it)
        if case .streaming(let assistantId) = state {
            // Flush any pending deltas and mark as sent
            await flushDeltaNow(assistantId)
            try? await repo.setStatus(messageId: assistantId, status: .sent, error: nil)
        }
        state = .idle
    }

    // MARK: - Internals

    private func runStreamChain(history: [ChatMessage],
                                userMessage: ChatMessage,
                                continuation: AsyncStream<ChatEngineEvent>.Continuation) async {
        do {
            try await repo.upsert(userMessage)
            continuation.yield(.messageAppended(userMessage))

            let baseHistory = history + [userMessage]
            try await consumeStream(history: baseHistory, outputs: [], continuation: continuation)

            while true {
                let outs = drainPendingStreamedToolOutputs()   // no await needed; we’re on the actor
                if outs.isEmpty { break }
                let hist = try await repo.loadMessages(conversationId: conversationId, limit: nil)
                try await consumeStream(history: hist, outputs: outs, continuation: continuation)
            }
        } catch is CancellationError {
        } catch {
            print("***** \(error)")
            await setState(.failed("\(error)"), continuation: continuation)
        }
        continuation.finish()
    }
    
    private func consumeStream(history: [ChatMessage],
                               outputs: [ToolOutput],
                               continuation: AsyncStream<ChatEngineEvent>.Continuation) async throws {
        let stream = try ai.generate(conversationId: conversationId,
                                     history: history,
                                     output: outputs,
                                     supportsTools: true)
        for try await event in stream {
            try Task.checkCancellation()
            await self.handleAIEvent(event, continuation: continuation)
        }
    }
    
    private func cancelCurrentStreamIfAny() {
        currentStreamTask?.cancel()
        currentStreamTask = nil
    }

    private func handleAIEvent(_ event: AIEvent, continuation: AsyncStream<ChatEngineEvent>.Continuation) async {
        switch event {
        case .started(let id):
            // Create assistant placeholder
            let assistant = ChatMessage(
                id: id,
                conversationId: conversationId,
                role: .assistant,
                plain: "",
                createdAt: Date(),
                status: .streaming
            )
            try? await repo.upsert(assistant)
            continuation.yield(.messageAppended(assistant))
            await setState(.streaming(assistantId: id), continuation: continuation)

        case .delta(let id, let delta):
            // Yield to UI and debounce persistence
            continuation.yield(.messageDelta(messageId: id, delta: delta))
            await bufferDelta(id: id, delta: delta)

        case .toolCall(let name, let argsJSON):
            await runSingleTool(name: name, argsJSON: argsJSON, continuation: continuation)

        case .toolBatch(let calls):
            await runToolBatch(calls, continuation: continuation)

        case .suggestions(let chips):
            continuation.yield(.suggestions(chips))

        case .completed(let id):
            // Final flush + mark sent
            await flushDeltaNow(id)
            try? await repo.setStatus(messageId: id, status: .sent, error: nil)
            continuation.yield(.messageStatusUpdated(messageId: id, status: .sent, error: nil))
            continuation.yield(.completed(messageId: id))
            await setState(.idle, continuation: continuation)

        case .responseCreated(let rid):
            continuation.yield(.responseCreated(rid))
            await setState(.awaitingTools(responseId: rid, assistantId: currentAssistantIdIfAny()), continuation: continuation)
        }
    }
    
    private func drainPendingStreamedToolOutputs() -> [ToolOutput] {
        let outs = pendingStreamedToolOutputs
        pendingStreamedToolOutputs.removeAll()
        return outs
    }

    private func currentAssistantIdIfAny() -> UUID? {
        if case .streaming(let a) = state { return a }
        return nil
    }

    private func setState(_ new: ChatStreamState, continuation: AsyncStream<ChatEngineEvent>.Continuation) async {
        state = new
        continuation.yield(.stateChanged(new))
    }
    
    private func setCurrentStreamTask(_ task: Task<Void, Never>?) {
        currentStreamTask = task
    }

    private func cancelCurrentStreamTask() {
        currentStreamTask?.cancel()
        currentStreamTask = nil
    }

    // Debounce persistence of deltas to reduce I/O
    private func bufferDelta(id: UUID, delta: String) async {
        deltaBuffers[id, default: ""].append(delta)
        if deltaFlushTasks[id] == nil {
            deltaFlushTasks[id] = Task { [weak self] in
                try? await Task.sleep(nanoseconds: self?.deltaFlushNs ?? 150_000_000)
                await self?.flushDeltaNow(id)
            }
        }
    }

    private func flushDeltaNow(_ id: UUID) async {
        deltaFlushTasks[id]?.cancel()
        deltaFlushTasks[id] = nil
        guard let buf = deltaBuffers[id], !buf.isEmpty else { return }
        deltaBuffers[id] = ""
        try? await repo.appendDelta(messageId: id, delta: buf, status: .streaming)
    }

    // MARK: Tools

    private func runSingleTool(name: String, argsJSON: String, continuation: AsyncStream<ChatEngineEvent>.Continuation) async {
        do {
            let env = AIToolEnvelope(name: name, argsJSON: argsJSON)
            let result = try await tools.dispatch(env)
            let toolMsg = ChatMessage(
                conversationId: conversationId,
                role: .tool,
                plain: result.note,
                createdAt: Date(),
                status: .sent
            )
            try? await repo.upsert(toolMsg)
            continuation.yield(.messageAppended(toolMsg))
        } catch {
            let toolMsg = ChatMessage(
                conversationId: conversationId,
                role: .tool,
                plain: "⚠️ Tool error: \(error.localizedDescription)",
                createdAt: Date(),
                status: .sent
            )
            try? await repo.upsert(toolMsg)
            continuation.yield(.messageAppended(toolMsg))
        }
    }

    private func runToolBatch(_ calls: [ToolCallRequest], continuation: AsyncStream<ChatEngineEvent>.Continuation) async {
        var outputs: [ToolOutput] = []
        var notes: [String] = []
        var inserts: [ChatInsert] = []

        for c in calls {
            do {
                let env = AIToolEnvelope(name: c.name, argsJSON: c.argumentsJSON)
                let result = try await tools.dispatch(env)
                notes.append("• \(result.note)")
                if let ui = result.ui { inserts.append(ui) }
                outputs.append(ToolOutput(
                    previous_response_id: c.responseId,
                    tool_call_id: c.callId,
                    output: String((result.ui?.text ?? AttributedString(stringLiteral: "")).characters)
                ))
            } catch {
                let fail = "• \(c.name) failed: \(error.localizedDescription)"
                notes.append(fail)
                outputs.append(ToolOutput(
                    previous_response_id: c.responseId,
                    tool_call_id: c.callId,
                    output: fail
                ))
            }
        }

        if let required = calls.first(where: { $0.origin == .requiredAction }) {
            // Exactly-once submit to required-action response id
            do {
                try await ai.submitToolOutputs(responseId: required.responseId, outputs: outputs)
            } catch {
                let m = ChatMessage(conversationId: conversationId, role: .tool, plain: "⚠️ Submit tool outputs failed: \(error.localizedDescription)", createdAt: Date(), status: .sent)
                try? await repo.upsert(m)
                continuation.yield(.messageAppended(m))
            }
            await setState(.awaitingTools(responseId: required.responseId, assistantId: currentAssistantIdIfAny()), continuation: continuation)
        } else {
            // Streamed function_call path → accumulate outputs for a follow-up turn,
            // and (optionally) show a compact tool bubble now.
            pendingStreamedToolOutputs.append(contentsOf: outputs)

            // Optional: visible summary bubble (keep or remove to taste)
            let summaryText = (["🔧 Ran \(calls.count) tool(s):"] + notes).joined(separator: "\n")
////            let text = inserts.first?.text ?? summaryText
//            let m = ChatMessage(conversationId: conversationId,
//                                role: .tool,
//                                plain: summaryText,
//                                createdAt: Date(),
//                                status: .sent)
//            try? await repo.upsert(m)
//            continuation.yield(.messageAppended(m))

            // IMPORTANT: do NOT call ai.submitToolOutputs here.
            // The follow-up turn will be kicked off after the current stream completes.
        }
    }
}

// MARK: - Debouncer for UI (MainActor)

@MainActor
final class Debouncer {
    private var task: Task<Void, Never>?
    func schedule(afterNs: UInt64 = 120_000_000, _ block: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { [block] in
            try? await Task.sleep(nanoseconds: afterNs)
            block()
        }
    }
    func cancel() { task?.cancel(); task = nil }
}
