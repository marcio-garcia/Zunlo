//
//  ChatScreenViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SwiftUI
import GlowUI
import ZunloHelpers

// MARK: - ViewModel (UI-focused)

@MainActor
public final class ChatViewModel: ObservableObject {
    // UI state
    @Published public private(set) var messages: [ChatMessage] = []
    @Published public private(set) var daySections: [DaySection] = []
    @Published public private(set) var lastMessageAnchor: UUID?

    @Published public var input: String = ""
    @Published public var isGenerating: Bool = false
    @Published public var suggestions: [String] = []
    @Published private(set) var currentResponseId: String?

    public let conversationId: UUID

    private let engine: ChatEngine
    private let repo: ChatRepository

    // Deterministic calendar/formatting for stable section ids
    private let calendar: Calendar

    private let rebuildDebouncer = Debouncer()
    
    let markdownConverterConfig = MarkdownConverterConfig(
        heading1Font: AppFontStyle.title.font(),
        heading2Font: AppFontStyle.subtitle.font(),
        heading3Font: AppFontStyle.heading.font(),
        bodyFont: AppFontStyle.body.font(),
        boldFont: AppFontStyle.strongBody.font(),
        codeFont: AppFontStyle.caption.font(),
        codeBackgroundColor: Color.theme.surface,
        linkColor: Color.theme.accent
    )

    public init(
        conversationId: UUID,
        engine: ChatEngine,
        repo: ChatRepository,
        calendar: Calendar
    ) {
        self.conversationId = conversationId
        self.engine = engine
        self.repo = repo
        self.calendar = calendar
    }

    // MARK: Loading / Display

    public func loadHistory(limit: Int? = 200) async {
        do {
            messages = try await engine.loadHistory(limit: limit)
            rebuildSections()
        } catch {
            // Surface minimally; in production route to a banner/system bubble
            print("Failed to load chat: \(error)")
        }
    }

    public func displayMessageText(_ msg: ChatMessage) -> AttributedString {
        switch msg.format {
        case .plain:
            return AttributedString(msg.rawText)
        case .markdown:
            return MarkdownConverter.convertToAttributedString(msg.rawText, config: markdownConverterConfig)
        case .rich:
            return MarkdownConverter.convertToAttributedString(msg.rawText, config: markdownConverterConfig)
        }
    }
    
    // MARK: Sending / Streaming

    public func send(text: String? = nil, attachments: [ChatAttachment] = [], userId: UUID? = nil) async {
        let trimmed = (text ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }

        // Clear UI affordances
        input = ""
        suggestions = []
        isGenerating = true

        // 1) Append local user bubble immediately for responsiveness
        let userMessage = ChatMessage(
            conversationId: conversationId,
            role: .user,
            attributed: AttributedString(stringLiteral: trimmed),
            createdAt: Date(),
            status: .sent,
            userId: userId,
            attachments: attachments
        )
        messages.append(userMessage)
        rebuildSections()

        // 2) Start engine stream and react to events
        let historySnapshot = messages // pass snapshot to engine
        Task { [weak self] in
            guard let self else { return }
            let stream = await engine.startStream(history: historySnapshot, userMessage: userMessage)
            for await ev in stream { await self.consume(ev) }
        }
    }

    public func stopGeneration() {
        isGenerating = false
        Task { await engine.stop() }
    }

    public func retry(failedAssistantId: UUID) async {
        // Find the user message immediately preceding this assistant
        guard let failedIndex = messages.firstIndex(where: { $0.id == failedAssistantId && $0.status == .failed }) else { return }
        let prevUser = messages[..<failedIndex].last { $0.role == .user }
        guard let userMessage = prevUser else { return }
        await send(text: userMessage.rawText)
    }

    public func delete(messageId: UUID) async {
        if let idx = messages.firstIndex(where: { $0.id == messageId }) {
            messages.remove(at: idx)
            rebuildSections()
        }
        try? await repo.delete(messageId: messageId)
    }

    public func deleteAll() async {
        messages.removeAll()
        rebuildSections()
        try? await repo.deleteAll(conversationId)
    }

    // MARK: Consume Engine Events

    private func consume(_ ev: ChatEngineEvent) async {
        switch ev {
        case .messageAppended(let m):
            upsertLocal(m)
            if m.role == .assistant { lastMessageAnchor = m.id }
            rebuildSections()

        case .messageDelta(let id, let delta):
            if let idx = messages.firstIndex(where: { $0.id == id }) {
                messages[idx].rawText += delta
                messages[idx].status = .streaming
                // Debounce expensive section rebuilds during token bursts
                rebuildDebouncer.schedule { [weak self] in self?.rebuildSections() }
            }

        case .messageStatusUpdated(let id, let status, _):
            if let idx = messages.firstIndex(where: { $0.id == id }) {
                print("update status: \(id) - \(messages[idx].rawText)")
                if status == .deleted {
                    messages.remove(at: idx)
                } else {
                    messages[idx].status = status
                }
            }
            rebuildSections()

        case .messageFormatUpdated(let id, let format):
            if let idx = messages.firstIndex(where: { $0.id == id }) {
                print("format \(format.rawValue) for \(id) \(messages[idx].rawText) ")
                messages[idx].format = format
                rebuildSections() // optional; only if your cell depends on format for layout
            }
        
        case .suggestions(let chips):
            suggestions = chips

        case .responseCreated(let rid):
            currentResponseId = rid

        case .stateChanged(let s):
            switch s {
            case .idle:
                print("IDLE:")
                isGenerating = false
            case .streaming(let assistantId):
                print("STREAMING - assistent id: \(assistantId)")
                isGenerating = true
            case .awaitingTools(let responseId, let assistantId):
                print("AWAITINGTOOLS - response id: \(responseId) -  assistent id: \(assistantId?.uuidString ?? "nil")")
                isGenerating = true
            case .stopped(let assistantId):
                isGenerating = false
                if let id = assistantId, let idx = messages.firstIndex(where: { $0.id == id }) {
                    messages.remove(at: idx)
                    rebuildSections()
                }
            case .failed(let msg):
                isGenerating = false
                print("Stream failed: \(msg)")
            }

        case .completed:
            currentResponseId = nil
            rebuildSections()
        }
    }

    private func upsertLocal(_ message: ChatMessage) {
        if let idx = messages.firstIndex(where: { $0.id == message.id }) {
            messages[idx] = message
        } else {
            messages.append(message)
        }
    }

    // MARK: Grouping

    private func rebuildSections() {
        let groups = Dictionary(grouping: messages) { calendar.startOfDay(for: $0.createdAt) }
        let sortedDays = groups.keys.sorted()
        daySections = sortedDays.map { day in
            let items = (groups[day] ?? []).sorted { $0.createdAt < $1.createdAt }
            return DaySection(id: day.formattedDate(dateFormat: .inverted, calendar: calendar), date: day, items: items)
        }
        lastMessageAnchor = messages.last?.id
    }
}


extension ChatViewModel {
    // Called by MessageBubble.onAction
    func handleBubbleAction(_ action: ChatMessageAction, message: ChatMessage) {
        switch action {
        case .copyText:
            copyToClipboard(message.rawText)

        case .copyAttachment(let attachmentId):
            guard let att = message.attachments.first(where: { $0.id == attachmentId }),
                  let json = att.decodedString() else { return }
            copyToClipboard(json)

        case .sendAttachmentToAI(let attachmentId):
            guard let att = message.attachments.first(where: { $0.id == attachmentId }),
                  let data = Data(base64Encoded: att.dataBase64) else { return }
            Task {
                await sendAttachmentToAI(schema: att.schema, mime: att.mime, data: data)
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        #endif
    }

    // user-triggered “Send it to me” that creates a new user turn
    private func sendAttachmentToAI(schema: String?, mime: String, data: Data) async {
        let attachments = [
            ChatAttachment(
                id: UUID(), mime: mime, schema: schema,
                filename: "payload.json", dataBase64: data.base64EncodedString()
            )
        ]
        await send(
            text: String(localized: "Please analyze the attached data."),
            attachments: attachments,
            userId: nil
        )
    }

}
