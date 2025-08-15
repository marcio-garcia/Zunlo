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

    public let conversationId: UUID
    private let repository: ChatRepository
    private let ai: AIClient
    private let userId: UUID?

    private let calendar = Calendar.current
    private let iso8601 = ISO8601DateFormatter()

    public init(
        conversationId: UUID,
        repository: ChatRepository,
        ai: AIClient,
        userId: UUID? = nil
    ) {
        self.conversationId = conversationId
        self.repository = repository
        self.ai = ai
        self.userId = userId
    }

    // MARK: Loading

    public func loadHistory(limit: Int? = 200) async {
        do {
            messages = try await repository.loadMessages(conversationId: conversationId, limit: limit)
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

        do { try await repository.upsert(userMessage) } catch { print("Upsert user msg error: \(error)") }

        // 2) Generate assistant reply
        isGenerating = true
        var replyId: UUID?

        do {
            let stream = ai.generate(
                conversationId: conversationId,
                history: messages,
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
                    try await repository.upsert(assistant)

                case .delta(let id, let delta):
                    if let idx = messages.firstIndex(where: { $0.id == id }) {
                        messages[idx].text += delta
                        messages[idx].status = .streaming
                        try await repository.appendDelta(messageId: id, delta: delta, status: .streaming)
                    }

                case .toolCall(let name, let argsJSON):
                    await handleToolCall(name: name, argsJSON: argsJSON)

                case .suggestions(let chips):
                    suggestions = chips

                case .completed(let id):
                    if let idx = messages.firstIndex(where: { $0.id == id }) {
                        messages[idx].status = .sent
                        try await repository.setStatus(messageId: id, status: .sent, error: nil)
                    }
                    isGenerating = false
                }
            }
        } catch {
            isGenerating = false
            if let id = replyId, let idx = messages.firstIndex(where: { $0.id == id }) {
                messages[idx].status = .failed
                messages[idx].errorDescription = "\(error)"
                try? await repository.setStatus(messageId: id, status: .failed, error: "\(error)")
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
        ai.cancelCurrentGeneration()
        isGenerating = false
        if let last = messages.last, last.role == .assistant {
            Task { try? await repository.setStatus(messageId: last.id, status: .sent, error: nil) }
        }
    }

    public func delete(messageId: UUID) async {
        if let idx = messages.firstIndex(where: { $0.id == messageId }) {
            messages.remove(at: idx)
            rebuildSections()
        }
        try? await repository.delete(messageId: messageId)
    }

    // MARK: Tools

    private func handleToolCall(name: String, argsJSON: String) async {
        // Stub – when tools are implemented, decode args and call into app services.
        let toolResult = ChatMessage(
            conversationId: conversationId,
            role: .tool,
            text: "Tool \(name) would run here with args: \(argsJSON)",
            status: .sent
        )
        messages.append(toolResult)
        rebuildSections()
        try? await repository.upsert(toolResult)
    }

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
}
