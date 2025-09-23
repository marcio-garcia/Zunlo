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
import SmartParseKit
import LoggingKit
import GlowUI

// LocalProcessor - Handles local NLP processing and tool execution
// MessagePersistence - Handles message persistence with debounced delta buffering
// StreamManager - Handles AI streaming and remote tool calls
// ChatEngine - Main coordinator that orchestrates the components

public actor ChatEngine {
    public let conversationId: UUID

    // Component dependencies
    private let localProcessor: LocalProcessor
    private let streamManager: StreamManager
    private let persistence: MessagePersistence

    // State management
    private(set) var state: ChatStreamState = .idle
    private var currentStreamTask: Task<Void, Never>?
    private var currentChatEvent: ((ChatEngineEvent) -> Void)?

    // Active command processing context
    private var commandContexts: [CommandContext] = []
    private var toolResults: [ToolResult] = []

    init(
        conversationId: UUID,
        ai: AIChatService,
        nlpService: NLProcessing,
        repo: ChatRepository,
        localTools: Tools,
        calendar: Calendar
    ) {
        self.conversationId = conversationId
        self.persistence = MessagePersistence(repo: repo)
        self.localProcessor = LocalProcessor(nlpService: nlpService, localTools: localTools, calendar: calendar)
        self.streamManager = StreamManager(ai: ai, persistence: persistence, localTools: localTools, conversationId: conversationId)
    }

    // Load history via persistence layer
    func loadHistory(limit: Int? = 200) async throws -> [ChatMessage] {
        try await persistence.loadMessages(conversationId: conversationId, limit: limit)
    }
    
    /// Main entry point: Try local processing first, fallback to AI streaming
    func run(history: [ChatMessage], userMessage: ChatMessage, chatEvent: @escaping (ChatEngineEvent) -> Void) async {
        // Store the chat event callback for state communication
        currentChatEvent = chatEvent

        // Start with a placeholder UUID for streaming state
        let placeholderAssistantId = UUID()
        setState(.streaming(assistantId: placeholderAssistantId))

        do {
            // Echo user message first
            try await persistence.upsert(userMessage)
            chatEvent(.messageAppended(userMessage))

            // LOCAL PATH: Try processing with NLP + local tools first
            commandContexts = try await localProcessor.processInput(userMessage.rawText.lowercased())

            for context in commandContexts {
                if context.hasIntentAmbiguity {
                    // Handle intent disambiguation
                    let result = await localProcessor.createIntentDisambiguationMessage(context: context)
                    toolResults.append(result)
                } else {
                    // Execute through local tools
                    let result = try await localProcessor.execute(context)
                    log("Local tool result: \(result)")
                    toolResults.append(result)
                }
            }

            // Stream local results to UI
            await processLocalResults(toolResults: toolResults, chatEvent: chatEvent)

        } catch {
            // REMOTE PATH: Local processing failed, fallback to AI streaming
            log("Local processing failed, falling back to AI: \(error)")
            await fallbackToAIStream(history: history, userMessage: userMessage, chatEvent: chatEvent)
        }
    }
    
    /// Process local tool results and stream to UI
    private func processLocalResults(toolResults: [ToolResult], chatEvent: (ChatEngineEvent) -> Void) async {
        for result in toolResults {
            switch result.action {
            case .none:
                // No local result → would need to fallback to AI streaming
                // Note: This case shouldn't happen in normal disambiguation flow
                log("Warning: Tool result with .none action in local processing")
            default:
                // Stream local processing result to UI
                let stream = createLocalResultStream(result: result)
                for await event in stream {
                    chatEvent(event)
                }
            }
        }
    }

    /// Fallback to AI streaming when local processing fails or is not applicable
    private func fallbackToAIStream(history: [ChatMessage], userMessage: ChatMessage, chatEvent: (ChatEngineEvent) -> Void) async {
        let stream = await streamManager.startStream(history: history, userMessage: userMessage)
        for await event in stream {
            chatEvent(event)
        }
    }
    
    /// Create a stream for local tool results (simulates AI streaming for consistency)
    private func createLocalResultStream(result: ToolResult) -> AsyncStream<ChatEngineEvent> {
        cancelCurrentStreamIfAny()

        return AsyncStream<ChatEngineEvent> { continuation in
            currentStreamTask = Task { [weak self] in
                guard let self else { return }
                do {
                    // Build the assistant message from local tool result
                    var assistant = await self.createAssistantMessage(
                        conversationId: self.conversationId,
                        rawText: result.message,
                        richText: result.richText,
                        status: .streaming,
                        actions: result.options
                    )

                    // Stream events to the UI
                    continuation.yield(.messageAppended(assistant))

                    // Simulate brief processing delay for better UX
                    try await Task.sleep(for: .seconds(1))

                    assistant.status = .sent
                    continuation.yield(.messageStatusUpdated(messageId: assistant.id, status: .sent, error: nil))

                    // Persist final message
                    try await self.persistence.upsert(assistant)

                    continuation.yield(.completed(messageId: assistant.id))

                    // Return engine to idle
                    await self.setState(.idle)

                } catch is CancellationError {
                    await self.setState(.failed("Chat cancelled"))
                } catch {
                    log("Local result streaming error: \(error)")
                    await self.setState(.failed("\(error)"))
                }
                continuation.finish()
            }

            // Cleanup on termination
            continuation.onTermination = { [weak self] _ in
                Task { await self?.cancelCurrentStreamIfAny() }
            }
        }
    }

    /// Public API for starting AI streaming (delegates to StreamManager)
    func startStream(history: [ChatMessage], userMessage: ChatMessage, output: [ToolOutput] = []) async -> AsyncStream<ChatEngineEvent> {
        return await streamManager.startStream(history: history, userMessage: userMessage, output: output)
    }

    public func stop() async {
        // Cancel current processing
        cancelCurrentStreamIfAny()

        // Delegate streaming cancellation to StreamManager
        await streamManager.cancelCurrentGeneration()

        // Update state
        setState(.idle)
    }

    // MARK: - Disambiguation Handling

    /// Handle user selection of a disambiguation option
    func handleDisambiguationSelection(commandContextId: UUID, selectedOptionId: UUID, chatEvent: @escaping (ChatEngineEvent) -> Void) async {
        // Store the chat event callback for state communication
        currentChatEvent = chatEvent

        guard let originalContext = commandContexts.first(where: { $0.id == commandContextId }) else { return }

        if originalContext.hasIntentAmbiguity {
            await handleIntentDisambiguation(originalContext: originalContext, selectedOptionId: selectedOptionId, chatEvent: chatEvent)
        } else {
            await handleEntityDisambiguation(contextId: commandContextId, selectedOptionId: selectedOptionId, chatEvent: chatEvent)
        }
    }

    private func handleIntentDisambiguation(originalContext: CommandContext, selectedOptionId: UUID, chatEvent: (ChatEngineEvent) -> Void) async {
        guard let intentAmbiguity = originalContext.intentAmbiguity,
              let selectedIntent = intentAmbiguity.predictions.first(where: { $0.id == selectedOptionId })?.intent else { return }

        let resolvedContext = originalContext.withSelectedIntent(selectedIntent)
        commandContexts.append(resolvedContext)

        do {
            let result = try await localProcessor.execute(resolvedContext)
            self.toolResults = [result]
            await processLocalResults(toolResults: self.toolResults, chatEvent: chatEvent)
        } catch {
            // Create user message for AI fallback
            let userMessage = ChatMessage(conversationId: conversationId, role: .user, plain: originalContext.originalText)
            await fallbackToAIStream(history: [], userMessage: userMessage, chatEvent: chatEvent)
        }
    }

    private func handleEntityDisambiguation(contextId: UUID, selectedOptionId: UUID, chatEvent: (ChatEngineEvent) -> Void) async {
        guard let originalContext = commandContexts.first(where: { $0.id == contextId }),
              let toolResult = toolResults.first(where: { result in
                  result.options.contains { $0.commandContextId == contextId }
              }),
              let selectedOption = toolResult.options.first(where: { $0.id == selectedOptionId }) else {
            return
        }

        // For events, we need to store the entire occurrence since IDs are not persistent for recurring events
        let resolvedContext: CommandContext
        if let eventOccurrence = selectedOption.eventOccurrence {
            // For events, store the full occurrence in the context
            resolvedContext = originalContext.withSelectedEventOccurrence(eventOccurrence, editMode: selectedOption.editEventMode)
        } else if let taskId = selectedOption.taskId {
            // For tasks, we can use the persistent ID directly
            resolvedContext = originalContext.withSelectedEntity(taskId, editMode: selectedOption.editEventMode)
        } else {
            // Fallback to the option ID
            resolvedContext = originalContext.withSelectedEntity(selectedOption.id, editMode: selectedOption.editEventMode)
        }
        commandContexts.append(resolvedContext)

        do {
            let result = try await localProcessor.execute(resolvedContext)
            self.toolResults = [result]
            await processLocalResults(toolResults: self.toolResults, chatEvent: chatEvent)
        } catch {
            // Create user message for AI fallback
            let userMessage = ChatMessage(conversationId: conversationId, role: .user, plain: originalContext.originalText)
            await fallbackToAIStream(history: [], userMessage: userMessage, chatEvent: chatEvent)
        }
    }

    // MARK: - Internal Helpers

    private func cancelCurrentStreamIfAny() {
        currentStreamTask?.cancel()
        currentStreamTask = nil
    }

    private func setState(_ newState: ChatStreamState) {
        state = newState
        currentChatEvent?(.stateChanged(newState))
    }

    private func createAssistantMessage(conversationId: UUID, id: UUID? = nil, rawText: String? = nil, richText: AttributedString? = nil, status: ChatMessageStatus, actions: [ChatMessageActionAlternative]) -> ChatMessage {
        if let rich = richText {
            return ChatMessage(id: id ?? UUID(), conversationId: conversationId, role: .assistant, attributed: rich, createdAt: Date(), status: status, actions: actions)
        } else {
            return ChatMessage(id: id ?? UUID(), conversationId: conversationId, role: .assistant, plain: rawText ?? "", createdAt: Date(), status: status, actions: actions)
        }
    }
}
