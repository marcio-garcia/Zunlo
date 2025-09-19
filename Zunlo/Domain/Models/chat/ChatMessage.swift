//
//  ChatMessage.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation
import ZunloHelpers
import SmartParseKit

// MARK: - Core Models

public enum ChatRole: String, Codable {
    case user, assistant, system, tool
}

public enum ChatMessageStatus: String, Codable {
    case sending, streaming, sent, failed, deleted
}

public enum ChatMessageFormat: String, Codable {
    case plain       // render literally
    case markdown    // parse as Markdown
    case rich        // use provided AttributedString
}

struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let conversationId: UUID
    let role: ChatRole
    var rawText: String
    var richText: AttributedString?
    let createdAt: Date
    var status: ChatMessageStatus
    var format: ChatMessageFormat
    var userId: UUID?
    var attachments: [ChatAttachment]
    var actions: [ChatMessageActionAlternative]
    var parentId: UUID?
    var errorDescription: String?
}

extension ChatMessage {
    public init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: ChatRole,
        plain text: String,
        createdAt: Date = Date(),
        status: ChatMessageStatus = .sent,
        userId: UUID? = nil,
        attachments: [ChatAttachment] = [],
        actions: [ChatMessageActionAlternative] = [],
        parentId: UUID? = nil,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.rawText = text
        self.format = .plain
        self.richText = nil
        self.createdAt = createdAt
        self.status = status
        self.userId = userId
        self.attachments = attachments
        self.actions = actions
        self.parentId = parentId
        self.errorDescription = errorDescription
    }
    
    public init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: ChatRole,
        markdown md: String,
        richText: AttributedString? = nil,
        createdAt: Date = Date(),
        status: ChatMessageStatus = .sent,
        userId: UUID? = nil,
        attachments: [ChatAttachment] = [],
        actions: [ChatMessageActionAlternative] = [],
        parentId: UUID? = nil,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.rawText = md
        self.format = .markdown
        self.richText = richText
        self.createdAt = createdAt
        self.status = status
        self.userId = userId
        self.attachments = attachments
        self.actions = actions
        self.parentId = parentId
        self.errorDescription = errorDescription
    }
    
    public init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: ChatRole,
        attributed attr: AttributedString,
        createdAt: Date = Date(),
        status: ChatMessageStatus = .sent,
        userId: UUID? = nil,
        attachments: [ChatAttachment] = [],
        actions: [ChatMessageActionAlternative] = [],
        parentId: UUID? = nil,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.rawText = String(attr.characters) // fallback/for search
        self.format = .rich
        self.richText = attr
        self.createdAt = createdAt
        self.status = status
        self.userId = userId
        self.attachments = attachments
        self.actions = actions
        self.parentId = parentId
        self.errorDescription = errorDescription
    }
}

// MARK: - Bridging: Realm -> Model

extension ChatMessage {
    init(local: ChatMessageLocal) {
        self.id = local.id
        self.conversationId = local.conversationId
        self.role = ChatRole(rawValue: local.roleRaw) ?? .assistant
        self.rawText = local.rawText
        self.format = local.format
        self.richText = local.richText
        self.createdAt = local.createdAt
        self.status = ChatMessageStatus(rawValue: local.statusRaw) ?? .sent
        self.userId = local.userId
        self.parentId = local.parentId
        self.errorDescription = local.errorDescription

        self.attachments = local.attachments.map { ChatAttachment(local: $0) }
        self.actions = local.actions.compactMap { ChatMessageActionAlternative(label: AttributedString($0)) }
    }
}

extension ChatMessage {
    /// What the UI should render.
    var displayAttributed: AttributedString {
        switch format {
        case .plain:
            return AttributedString(rawText) // verbatim (no markdown parsing)
        case .markdown:
            return richText ?? AttributedString(rawText)
        case .rich:
            return richText ?? AttributedString(rawText)
        }
    }
    
    /// Read/write surface for the message text as `AttributedString`.
    /// - get: mirrors `displayAttributed`
    /// - set: updates underlying storage based on current `format`
    var editableAttributed: AttributedString {
        get { displayAttributed }
        set {
            switch format {
            case .plain:
                // Keep only characters; no styling stored
                rawText = String(newValue.characters)

            case .markdown:
                // Source of truth is the markdown string.
                // If a styled value is assigned here, we keep only its characters.
                rawText = String(newValue.characters)
                richText = newValue

            case .rich:
                // Preserve full styling + keep a plain fallback for search/share
                richText = newValue
                rawText = String(newValue.characters)
            }
        }
    }
    
    mutating func setPlain(_ text: String) {
        format = .plain
        rawText = text
    }

    mutating func setMarkdown(_ md: String) {
        format = .markdown
        rawText = md
        richText = MarkdownConverter.convertToAttributedString(md)
    }

    mutating func setAttributed(_ attr: AttributedString) {
        format = .rich
        richText = attr
        rawText = String(attr.characters) // fallback for search/share
    }
}

public enum ChatMessageAction: Identifiable, Equatable, Hashable {
    case copyText
    case copyAttachment(UUID)          // attachmentId
    case sendAttachmentToAI(UUID)      // attachmentId
    case disambiguateIntent(alternatives: [String]) // intent options for disambiguation

    public var id: String {
        switch self {
        case .copyText: return "copyText"
        case .copyAttachment(let id): return "copyAttachment:\(id.uuidString)"
        case .sendAttachmentToAI(let id): return "sendToAI:\(id.uuidString)"
        case .disambiguateIntent: return "disambiguateIntent"
        }
    }

    public var title: String {
        switch self {
        case .copyText: return "Copy"
        case .copyAttachment: return "Copy JSON"
        case .sendAttachmentToAI: return "Send it to me"
        case .disambiguateIntent: return "Choose what you meant"
        }
    }
}
