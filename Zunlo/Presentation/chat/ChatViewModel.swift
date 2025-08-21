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

    private var pendingMessages: [ChatMessage] = []
    
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
//        let args = "{\"dateRange\":\"tomorrow\",\"start\":\"2025-08-21T00:00:00-03:00\",\"end\":\"2025-08-22T00:00:00-03:00\"}"
//        let req = ToolCallRequest(
//            id: "124",
//            name: "getAgenda",
//            argumentsJSON: args,
//            responseId: "345",
//            origin: ToolCallOrigin.streamed
//        )
//        await handleToolBatch([req])
//        return
        
        let trimmed = (text ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }
        
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
        await streamMsg(message: userMessage)
    }
    
    public func streamMsg(message: ChatMessage, output: [ToolOutput] = []) async {
        input = ""

        suggestions = []
        
        // Generate assistant reply
        isGenerating = true
        var replyId: UUID?

        do {
            messages.append(message)
            rebuildSections()
            try await chatRepo.upsert(message)
            
            let stream = try aiChatService.generate(
                conversationId: conversationId,
                history: messages,
                output: output,
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
                        print("***** message: \(messages[idx])")
                        rebuildSections()
                        try await chatRepo.setStatus(messageId: id, status: .sent, error: nil)
                    }
                    if !pendingMessages.isEmpty {
                        let msg = pendingMessages.removeFirst()
                        await streamMsg(message: msg)
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
                rebuildSections()
                try? await chatRepo.setStatus(messageId: id, status: .failed, error: "\(error)")
            }
        }
    }

    public func retry(messageId: UUID) async {
        guard let _ = messages.first(where: { $0.id == messageId && $0.status == .failed }) else { return }
        if let lastUser = messages.reversed().first(where: { $0.role == .user }) {
            await streamMsg(message: lastUser)
        }
    }

    public func stopGeneration() {
        aiChatService.cancelCurrentGeneration()
        isGenerating = false
        if var last = messages.last, last.role == .assistant {
            last.status = .sent
            rebuildSections()
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
        var inserts: [ChatInsert] = []
        
        for c in calls {
            do {
                let envelope = AIToolEnvelope(name: c.name, argsJSON: c.argumentsJSON)
                let result = try await toolRouter.dispatch(envelope)
                notes.append("• \(result.note)")
                if let chatInsert = result.ui {
                    inserts.append(chatInsert)
                }
                outputs.append(ToolOutput(
                    tool_call_id: c.id,
                    output: result.note // keep it short; model sees this
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
                
//                rebuildSections()
//                messages.append(m)
//                try? await chatRepo.upsert(m)
                return
            }

        } else {
            // Streamed function_call path: DON'T call tool_outputs.
            // Optionally: kick off a follow-up turn using the tool result if you want the model to narrate.
            // Optional: show a compact tool summary bubble
            let summary = (["🔧 Ran \(calls.count) tool(s):"] + notes).joined(separator: "\n")
            let text = inserts.first?.text ?? ""
            let m = ChatMessage(conversationId: conversationId, role: .tool, text: text, createdAt: Date(), status: .sent)
//            messages.append(m)
//            try? await chatRepo.upsert(m)
            if isGenerating {
                print("[VM] still streaming - add to pending")
                pendingMessages.append(m)
            } else {
                print("[VM] streaming done - send tool response")
//                messages.append(m)
                await streamMsg(message: m)
            }
        }
        
        // Insert any UI messages produced by tools (e.g., Agenda text + JSON attachment + actions)
//        for ins in inserts {
//            var chat = ChatMessage(
//                conversationId: conversationId,
//                role: .tool,
//                text: ins.text,
//                createdAt: Date(),
//                status: .sent
//            )
//            chat.attachments = ins.attachments
//            chat.actions = ins.actions
//            print("[VM] created tool response message")
//            if isGenerating {
//                print("[VM] still streaming - add to pending")
//                pendingMessages.append(chat)
//            } else {
//                print("[VM] streaming done - send tool response")
//                messages.append(chat)
//                try? await chatRepo.upsert(chat)
//                await streamMsg(message: chat)
//            }
//        }

        
    }
}

// MARK: Tools

extension ChatViewModel {
    private func handleToolCall(name: String, argsJSON: String) async {
        do {
            let env = try JSONDecoder.decoder().decode(AIToolEnvelope.self, from: Data("""
            {"name":"\(name)","arguments":\(argsJSON)}
            """.utf8))
            let result = try await toolRouter.dispatch(env)
            let m = ChatMessage(conversationId: conversationId, role: .tool, text: result.note, createdAt: Date(), status: .sent)
//            messages.append(m)
//            rebuildSections()
//            try? await chatRepo.upsert(m)
        } catch {
            let m = ChatMessage(conversationId: conversationId, role: .tool,
                                text: "⚠️ Tool error: \(error.localizedDescription)", createdAt: Date(), status: .sent)
//            messages.append(m)
//            rebuildSections()
//            try? await chatRepo.upsert(m)
        }
    }
}

extension ChatViewModel {
    // Called by MessageBubble.onAction
    func handleBubbleAction(_ action: ChatMessageAction, message: ChatMessage) {
        switch action {
        case .copyText:
            copyToClipboard(message.text)

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
        // Append a local user bubble so UI feels responsive
        var m = ChatMessage(conversationId: conversationId, role: .user,
                            text: String(localized: "Please analyze the attached data."),
                            createdAt: Date(), status: .sending)
        // Include the attachment so your aiChatService can pass it as a content part
        m.attachments = [
            ChatAttachment(
                id: UUID(), mime: mime, schema: schema,
                filename: "payload.json", dataBase64: data.base64EncodedString()
            )
        ]
//        messages.append(m)
//        rebuildSections()
//        try? await chatRepo.upsert(m)

        // Send through API
        await streamMsg(message: m)
        
        // Mark as sent
        if let idx = messages.firstIndex(where: { $0.id == m.id }) {
            messages[idx].status = .sent
        }
        
        rebuildSections()
    }

}
