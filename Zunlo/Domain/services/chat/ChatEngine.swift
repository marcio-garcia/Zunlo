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

// MARK: - ChatEngine (orchestrates streaming/tooling/persistence)

public actor ChatEngine {
    public let conversationId: UUID
    private let ai: AIChatService
    private let tools: ToolRouter
    private let repo: ChatRepository
    private let nlpService: NLProcessing
    
    private(set) var state: ChatStreamState = .idle
    private var currentStreamTask: Task<Void, Never>? = nil

    // Debounced delta buffers per assistant message
    private var deltaBuffers: [UUID: String] = [:]
    private var deltaFlushTasks: [UUID: Task<Void, Never>] = [:]
    private let deltaFlushNs: UInt64 = 150_000_000 // 150ms

    private var pendingStreamedToolOutputs: [ToolOutput] = []
    private var emittedText = Set<UUID>()      // assistant ids that streamed any text
    private var toolingAssistantId: UUID?      // the draft bubble we turned into a "processing" placeholder
    private var mdDetectors: [UUID: MarkdownFormatDetector] = [:]
    
    public init(
        conversationId: UUID,
        ai: AIChatService,
        nlpService: NLProcessing,
        tools: ToolRouter,
        repo: ChatRepository
    ) {
        self.conversationId = conversationId
        self.ai = ai
        self.nlpService = nlpService
        self.tools = tools
        self.repo = repo
    }

    // Load history via repo actor
    public func loadHistory(limit: Int? = 200) async throws -> [ChatMessage] {
        try await repo.loadMessages(conversationId: conversationId, limit: limit)
    }
    
    public func run(history: [ChatMessage], userMessage: ChatMessage) async -> AsyncStream<ChatEngineEvent> {
        let lower = userMessage.rawText.lowercased()
        do {
            let result = try await nlpService.process(text: lower)

            switch result.outcome {
            case .unknown:
                // No local handling → use regular AI streaming path
                return startStream(history: history, userMessage: userMessage)

            default:
                // Handle locally and stream ChatEngineEvent's to the ViewModel
                return AsyncStream<ChatEngineEvent> { continuation in
                    // Run the work on the actor, keep a handle for cancellation symmetry
                    self.setCurrentStreamTask(
                        Task { [weak self] in
                            guard let self else { return }
                            do {
                                // Persist + echo the user message (keeps repo in sync with UI snapshot)
                                try await self.repo.upsert(userMessage)
                                continuation.yield(.messageAppended(userMessage))

                                // Build the assistant message from NLP result
                                let assistant = await self.createAssistantMessage(
                                    conversationId: self.conversationId,
                                    rawText: result.message,
                                    richText: result.attributedString,
                                    status: .sent
                                )

                                // Persist + stream events to the UI
                                try await self.repo.upsert(assistant)
                                continuation.yield(.messageAppended(assistant))
                                continuation.yield(.messageStatusUpdated(messageId: assistant.id, status: .sent, error: nil))
                                continuation.yield(.completed(messageId: assistant.id))

                                // 4) Return engine to idle so the UI stops the spinner
                                await self.setState(.idle, continuation: continuation)
                            } catch is CancellationError {
                                await self.setState(.failed("Chat cancelled"), continuation: continuation)
                            } catch {
                                // If anything goes wrong in local handling, fall back to normal AI streaming
                                let stream = await self.startStream(history: history, userMessage: userMessage)
                                for await ev in stream {
                                    continuation.yield(ev)
                                }
                            }
                            continuation.finish()
                        }
                    )

                    // Ensure underlying task is torn down if the consumer stops early
                    continuation.onTermination = { [weak self] _ in
                        Task { await self?.cancelCurrentStreamTask() }
                    }
                }
            }
        } catch {
            // If NLP fails, just use the normal AI streaming path
            return startStream(history: history, userMessage: userMessage)
        }
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
        // Best-effort: mark last streaming assistant as sent (if we can infer it)
        if case .streaming(let assistantId, let continuation) = state {
            // Flush any pending deltas and mark as sent
            await flushDeltaNow(assistantId)
            if emittedText.contains(assistantId) {
                try? await repo.setStatus(messageId: assistantId, status: .sent, error: nil)
            } else {
                try? await repo.delete(messageId: assistantId)
            }
            emittedText.remove(assistantId)
            if toolingAssistantId == assistantId { toolingAssistantId = nil }
            await setState(.stopped(assistantId: assistantId), continuation: continuation)
        } else {
            state = .idle
        }
        cancelCurrentStreamIfAny()
        ai.cancelCurrentGeneration()
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
            if let id = currentAssistantIdIfAny() {
                await flushDeltaNow(id)
                try? await repo.setStatus(messageId: id, status: .failed, error: "Cancelled")
                continuation.yield(.messageStatusUpdated(messageId: id, status: .failed, error: "Cancelled"))
                emittedText.remove(id)
                if toolingAssistantId == id { toolingAssistantId = nil }
            }
            await setState(.failed("Chat cancelled"), continuation: continuation)
        } catch {
            if let id = currentAssistantIdIfAny() {
                await flushDeltaNow(id)
                try? await repo.setStatus(messageId: id, status: .failed, error: "\(error)")
                continuation.yield(.messageStatusUpdated(messageId: id, status: .failed, error: "\(error)"))
                emittedText.remove(id)
                if toolingAssistantId == id { toolingAssistantId = nil }
            }
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
            // If we were awaiting tools and left an ephemeral bubble, drop it now.
            if case .awaitingTools = state, let prior = toolingAssistantId, !emittedText.contains(prior) {
                try? await repo.delete(messageId: prior)
                continuation.yield(.messageStatusUpdated(messageId: prior, status: .deleted, error: nil))
                toolingAssistantId = nil
            }
            
            // Create assistant placeholder
            let assistant = createAssistantMessage(
                conversationId: conversationId,
                id: id,
                rawText: "",
                status: .streaming
            )
            mdDetectors[id] = MarkdownFormatDetector()
            
            try? await repo.upsert(assistant)
            continuation.yield(.messageAppended(assistant))
            await setState(.streaming(assistantId: id, continuation: continuation), continuation: continuation)

        case .delta(let id, let delta):
            // Yield to UI and debounce persistence
            continuation.yield(.messageDelta(messageId: id, delta: delta))
            emittedText.insert(id)
            await bufferDelta(id: id, delta: delta)

            if let det = mdDetectors[id], det.feed(delta) {
                mdDetectors[id] = det
                continuation.yield(.messageFormatUpdated(messageId: id, format: .markdown))
                try? await repo.setFormat(messageId: id, format: .markdown)
            }

        case .toolCall(let responseId, let name, let argsJSON):
            // If you track the last response id, use it here
            await setState(.awaitingTools(responseId: responseId.uuidString,
                                          assistantId: currentAssistantIdIfAny()),
                           continuation: continuation)
            await runSingleTool(name: name, argsJSON: argsJSON, continuation: continuation)

        case .toolBatch(let calls):
            // Flip to awaiting-tools as soon as we know tools are in play
            if let first = calls.first {
                await setState(.awaitingTools(responseId: first.responseId,
                                              assistantId: currentAssistantIdIfAny()),
                               continuation: continuation)
            }
            if let a = currentAssistantIdIfAny(), !emittedText.contains(a) {
                let toolNames = calls.map { $0.name }.joined(separator: ", ")
                var awaitingText = ""
                if EnvConfig.shared.environment == .dev {
                    awaitingText = "⏳ Using \(toolNames)…"
                } else {
                    awaitingText = "⏳ Thinking..."
                }
                continuation.yield(.messageDelta(messageId: a, delta: awaitingText))
                toolingAssistantId = a
            }
            await runToolBatch(calls, continuation: continuation)

        case .suggestions(let chips):
            continuation.yield(.suggestions(chips))

        case .completed(let id):
            // If this turn called tools and produced no text, keep the placeholder alive.
            if toolingAssistantId == id && !emittedText.contains(id) {
                // Do NOT flush/mark .sent or .idle; we're still awaiting tools.
                continuation.yield(.completed(messageId: id)) // optional; safe to keep/omit
                return
            }
            
            // Final chance to promote (in case last chunk tipped it over and repo call didn’t run)
            if let det = mdDetectors[id], det.decided {
                try? await repo.setFormat(messageId: id, format: .markdown)
                continuation.yield(.messageFormatUpdated(messageId: id, format: .markdown))
            }
            
            // Normal text-only path: Final flush + mark sent
            await flushDeltaNow(id)
            try? await repo.setStatus(messageId: id, status: .sent, error: nil)
            continuation.yield(.messageStatusUpdated(messageId: id, status: .sent, error: nil))
            continuation.yield(.completed(messageId: id))
            
            mdDetectors[id] = nil
            emittedText.remove(id)
            if toolingAssistantId == id { toolingAssistantId = nil }
            await setState(.idle, continuation: continuation)

        case .responseCreated(let rid):
            continuation.yield(.responseCreated(rid))
        }
    }
    
    private func drainPendingStreamedToolOutputs() -> [ToolOutput] {
        let outs = pendingStreamedToolOutputs
        pendingStreamedToolOutputs.removeAll()
        return outs
    }

    private func currentAssistantIdIfAny() -> UUID? {
        switch state {
        case .idle:
            return nil
        case .streaming(let assistantId, _):
            return assistantId
        case .awaitingTools(_, let assistantId):
            return assistantId
        case .stopped(let assistantId):
            return assistantId
        case .failed:
            return nil
        }
    }

    private func setState(_ new: ChatStreamState, continuation: AsyncStream<ChatEngineEvent>.Continuation?) async {
        state = new
        continuation?.yield(.stateChanged(new))
    }
    
    private func setCurrentStreamTask(_ task: Task<Void, Never>?) {
        currentStreamTask = task
    }

    private func cancelCurrentStreamTask() {
        currentStreamTask?.cancel()
        currentStreamTask = nil
    }

    private func createAssistantMessage(
        conversationId: UUID,
        id: UUID? = nil,
        rawText: String? = nil,
        richText: AttributedString? = nil,
        status: ChatMessageStatus
    ) -> ChatMessage {
        if let rich = richText {
            return ChatMessage(
                id: id ?? UUID(),
                conversationId: conversationId,
                role: .assistant,
                attributed: rich,
                createdAt: Date(),
                status: status
            )
        } else {
            return ChatMessage(
                id: id ?? UUID(),
                conversationId: conversationId,
                role: .assistant,
                plain: rawText ?? "",
                createdAt: Date(),
                status: status
            )
        }
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
        guard let buf = deltaBuffers[id], !buf.isEmpty else { deltaBuffers[id] = nil; return }
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
                plain: "Tool error: \(error.localizedDescription)",
                createdAt: Date(),
                status: .sent
            )
            try? await repo.upsert(toolMsg)
            continuation.yield(.messageAppended(toolMsg))
        }
    }

    private func runToolBatch(_ calls: [ToolCallRequest], continuation: AsyncStream<ChatEngineEvent>.Continuation) async {
        var outputs: [ToolOutput] = []
        var inserts: [ChatInsert] = []

        for c in calls {
            do {
                let env = AIToolEnvelope(name: c.name, argsJSON: c.argumentsJSON)
                let result = try await tools.dispatch(env)
                if let ui = result.ui { inserts.append(ui) }
                outputs.append(ToolOutput(
                    previous_response_id: c.responseId,
                    tool_call_id: c.callId,
                    output: result.note
                ))
            } catch {
                let fail = "• \(c.name) failed: \(error.localizedDescription)"
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
