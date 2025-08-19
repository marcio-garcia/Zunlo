//
//  ChatScreenViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SwiftUI

@MainActor
public final class ChatViewModel: ObservableObject {
    // Source messages (flat)
    @Published public private(set) var messages: [ChatMessage] = []

    // Grouped for UI
    @Published public private(set) var daySections: [DaySection] = []
    @Published public private(set) var lastMessageAnchor: UUID?

    // Input/UI state
    @Published public var input: String = ""
    @Published public var isGenerating: Bool = false
    @Published public var suggestions: [String] = []

    // AI response id
    @Published private(set) var currentResponseId: String?
    
    public let conversationId: UUID
    private let chatRepo: ChatRepository
    private let aiChatService: AIChatService
    private let toolRouter: AIToolRouter
    private let userId: UUID?

    private let calendar = Calendar.current
    private let iso8601 = ISO8601DateFormatter()

    public init(
        conversationId: UUID,
        userId: UUID? = nil,
        aiChatService: AIChatService,
        toolRouter: AIToolRouter,
        chatRepo: ChatRepository
    ) {
        self.conversationId = conversationId
        self.chatRepo = chatRepo
        self.aiChatService = aiChatService
        self.toolRouter = toolRouter
        self.userId = userId
    }

    // MARK: Loading

    public func loadHistory(limit: Int? = 200) async {
        do {
            messages = try await chatRepo.loadMessages(conversationId: conversationId, limit: limit)
            rebuildSections()
        } catch {
            print("Failed to load chat: \(error)")
        }
    }

    // MARK: Sending / Streaming

    public func send(text: String? = nil, attachments: [ChatAttachment] = []) async {
        let trimmed = (text ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }
        suggestions = []

        // 1) Persist user message
        let userMessage = ChatMessage(
            conversationId: conversationId,
            role: .user,
            text: trimmed,
            createdAt: Date(),
            status: .sent,
            userId: userId,
            attachments: attachments
        )
        messages.append(userMessage)
        rebuildSections()
        input = ""

        do { try await chatRepo.upsert(userMessage) } catch { print("Upsert user msg error: \(error)") }

        // 2) Generate assistant reply
        isGenerating = true
        var replyId: UUID?

        do {
            let historyTail = Array(messages.suffix(8))
            let stream = aiChatService.generate(
                conversationId: conversationId,
                history: historyTail,
                userInput: trimmed,
                attachments: attachments,
                supportsTools: true
            )

            for try await event in stream {
                switch event {
                case .started(let id):
                    replyId = id
                    let assistant = ChatMessage(
                        id: id,
                        conversationId: conversationId,
                        role: .assistant,
                        text: "",
                        createdAt: Date(),
                        status: .streaming
                    )
                    messages.append(assistant)
                    rebuildSections()
                    try await chatRepo.upsert(assistant)

                case .delta(let id, let delta):
                    if let idx = messages.firstIndex(where: { $0.id == id }) {
                        messages[idx].text += delta
                        messages[idx].status = .streaming
                        print("***** message delta: \(messages[idx])")
                        try await chatRepo.appendDelta(messageId: id, delta: delta, status: .streaming)
                        rebuildSections()
                    }

                case .toolCall(let name, let argsJSON):
                    await handleToolCall(name: name, argsJSON: argsJSON)

                case .toolBatch(let calls):
                    for c in calls {
                        print("[VM] tool call:", c.name, "args:", c.argumentsJSON)
                    }
                    await handleToolBatch(calls)
                    
                case .suggestions(let chips):
                    suggestions = chips

                case .completed(let id):
                    if let idx = messages.firstIndex(where: { $0.id == id }) {
                        messages[idx].status = .sent
                        try await chatRepo.setStatus(messageId: id, status: .sent, error: nil)
                    }
                    isGenerating = false
                case .responseCreated(let rid):
                    currentResponseId = rid
                }
            }
        } catch {
            isGenerating = false
            if let id = replyId, let idx = messages.firstIndex(where: { $0.id == id }) {
                messages[idx].status = .failed
                messages[idx].errorDescription = "\(error)"
                try? await chatRepo.setStatus(messageId: id, status: .failed, error: "\(error)")
            }
        }
    }

    public func retry(messageId: UUID) async {
        guard let _ = messages.first(where: { $0.id == messageId && $0.status == .failed }) else { return }
        if let lastUser = messages.reversed().first(where: { $0.role == .user }) {
            await send(text: lastUser.text)
        }
    }

    public func stopGeneration() {
        aiChatService.cancelCurrentGeneration()
        isGenerating = false
        if let last = messages.last, last.role == .assistant {
            Task { try? await chatRepo.setStatus(messageId: last.id, status: .sent, error: nil) }
        }
    }

    public func delete(messageId: UUID) async {
        if let idx = messages.firstIndex(where: { $0.id == messageId }) {
            messages.remove(at: idx)
            rebuildSections()
        }
        try? await chatRepo.delete(messageId: messageId)
    }

//    private func handleToolCall(name: String, argsJSON: String) async {
//        // Stub – when tools are implemented, decode args and call into app services.
//        let toolResult = ChatMessage(
//            conversationId: conversationId,
//            role: .tool,
//            text: "Tool \(name) would run here with args: \(argsJSON)",
//            status: .sent
//        )
//        messages.append(toolResult)
//        rebuildSections()
//        try? await repository.upsert(toolResult)
//    }

    // MARK: Grouping

    private func rebuildSections() {
        let groups = Dictionary(grouping: messages) { calendar.startOfDay(for: $0.createdAt) }
        let sortedDays = groups.keys.sorted()
        daySections = sortedDays.map { day in
            let items = (groups[day] ?? []).sorted { $0.createdAt < $1.createdAt }
            return DaySection(id: iso8601.string(from: day), date: day, items: items)
        }
        lastMessageAnchor = messages.last?.id
    }
    
    private func handleToolBatch(_ calls: [ToolCallRequest]) async {
        guard let responseId = calls.first?.responseId else { return }

        var outputs: [ToolOutput] = []
        var notes: [String] = []

        for c in calls {
            do {
                let env = try JSONDecoder.decoder().decode(AIToolEnvelope.self,
                    from: Data(#"{"name":"\#(c.name)","arguments":\#(c.argumentsJSON)}"#.utf8))
                let note = try await toolRouter.dispatch(env)
                notes.append("• \(note)")
                outputs.append(ToolOutput(
                    tool_call_id: c.id,
                    output: note // keep it short; model sees this
                ))
            } catch {
                let fail = "• \(c.name) failed: \(error.localizedDescription)"
                notes.append(fail)
                outputs.append(ToolOutput(
                    tool_call_id: c.id,
                    output: fail
                ))
            }
        }
        
        // 2) If any came from required_action → submit tool_outputs
        if let rid = calls.first(where: { $0.origin == .requiredAction })?.responseId {
            try? await aiChatService.submitToolOutputs(responseId: rid, outputs: outputs)
            // The original SSE stream should continue and produce more tokens.
            // Submit tool outputs so OpenAI can continue the same streaming response
            do {
                try await aiChatService.submitToolOutputs(responseId: responseId, outputs: outputs)
            } catch {
                // Surface error to chat
                let m = ChatMessage(conversationId: conversationId, role: .tool,
                                    text: "⚠️ Submit tool outputs failed: \(error.localizedDescription)",
                                    createdAt: Date(), status: .sent)
                messages.append(m)
                rebuildSections()
                try? await chatRepo.upsert(m)
                return
            }

        } else {
            // Streamed function_call path: DON'T call tool_outputs.
            // Optionally: kick off a follow-up turn using the tool result if you want the model to narrate.
            // Optional: show a compact tool summary bubble
            let summary = (["🔧 Ran \(calls.count) tool(s):"] + notes).joined(separator: "\n")
            let m = ChatMessage(conversationId: conversationId, role: .tool, text: summary, createdAt: Date(), status: .sent)
            messages.append(m)
            rebuildSections()
            try? await chatRepo.upsert(m)
        }
    }
}

// MARK: Tools

extension ChatViewModel {
    private func handleToolCall(name: String, argsJSON: String) async {
        do {
            let env = try JSONDecoder.decoder().decode(AIToolEnvelope.self, from: Data("""
            {"name":"\(name)","arguments":\(argsJSON)}
            """.utf8))
            let note = try await toolRouter.dispatch(env)
            let m = ChatMessage(conversationId: conversationId, role: .tool, text: note, createdAt: Date(), status: .sent)
            messages.append(m)
            rebuildSections()
            try? await chatRepo.upsert(m)
        } catch {
            let m = ChatMessage(conversationId: conversationId, role: .tool,
                                text: "⚠️ Tool error: \(error.localizedDescription)", createdAt: Date(), status: .sent)
            messages.append(m)
            rebuildSections()
            try? await chatRepo.upsert(m)
        }
    }
}


