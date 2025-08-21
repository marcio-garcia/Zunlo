//
//  ChatMessage.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation

// MARK: - Core Models

public enum ChatRole: String, Codable {
    case user, assistant, system, tool
}

public enum MessageStatus: String, Codable {
    case sending, streaming, sent, failed
}

public enum MessageFormat: String, Codable {
    case plain       // render literally
    case markdown    // parse as Markdown
    case rich        // use provided AttributedString
}

public struct ChatMessage: Identifiable, Hashable, Codable {
    public let id: UUID
    public let conversationId: UUID
    public let role: ChatRole
    public var rawText: String
    public var richText: AttributedString?
    public let createdAt: Date
    public var status: MessageStatus
    public var format: MessageFormat
    public var userId: UUID?
    public var attachments: [ChatAttachment]
    public var actions: [ChatMessageAction] = []
    public var parentId: UUID?
    public var errorDescription: String?
}

extension ChatMessage {
    public init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: ChatRole,
        plain text: String,
        createdAt: Date = Date(),
        status: MessageStatus = .sent,
        userId: UUID? = nil,
        attachments: [ChatAttachment] = [],
        actions: [ChatMessageAction] = [],
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
        self.parentId = parentId
        self.errorDescription = errorDescription
    }
    
    public init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: ChatRole,
        markdown md: String,
        createdAt: Date = Date(),
        status: MessageStatus = .sent,
        userId: UUID? = nil,
        attachments: [ChatAttachment] = [],
        actions: [ChatMessageAction] = [],
        parentId: UUID? = nil,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.rawText = md
        self.format = .markdown
        self.richText = nil
        self.createdAt = createdAt
        self.status = status
        self.userId = userId
        self.attachments = attachments
        self.parentId = parentId
        self.errorDescription = errorDescription
    }
    
    public init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: ChatRole,
        attributed attr: AttributedString,
        createdAt: Date = Date(),
        status: MessageStatus = .sent,
        userId: UUID? = nil,
        attachments: [ChatAttachment] = [],
        actions: [ChatMessageAction] = [],
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
        self.parentId = parentId
        self.errorDescription = errorDescription
    }
    
//    public static func plainText(_ text: String) {
//    }
//
//    public static func appendAssistantMarkdown(_ md: String) {
//        repo.ChatMessage(role: .assistant, markdown: md))
//    }
//
//    public static func appendAssistantRich(_ attr: AttributedString) {
//        repo.add(ChatMessage(role: .assistant, attributed: attr))
//    }
}

extension ChatMessage {
    /// What the UI should render.
    var displayAttributed: AttributedString {
        switch format {
        case .plain:
            return AttributedString(rawText) // verbatim (no markdown parsing)
        case .markdown:
            return (try? AttributedString(
                markdown: rawText,
                options: .init(allowsExtendedAttributes: true, interpretedSyntax: .full)
            )) ?? AttributedString(rawText)
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
                richText = nil

            case .markdown:
                // Source of truth is the markdown string.
                // If a styled value is assigned here, we keep only its characters.
                rawText = String(newValue.characters)
                richText = nil

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
        richText = nil
    }

    mutating func setMarkdown(_ md: String) {
        format = .markdown
        rawText = md
        richText = nil
    }

    mutating func setAttributed(_ attr: AttributedString) {
        format = .rich
        richText = attr
        rawText = String(attr.characters) // fallback for search/share
    }
}

public struct ChatAttachment: Identifiable, Equatable, Hashable, Codable {
    public let id: UUID
    public let mime: String            // e.g., "application/json"
    public let schema: String?         // e.g., "zunlo.agenda#1"
    public let filename: String?
    public let dataBase64: String      // store text JSON as utf8/base64
}

extension ChatAttachment {
    static func json(schema: String, json: String, filename: String? = nil) -> ChatAttachment {
        .init(
            id: UUID(),
            mime: "application/json",
            schema: schema,
            filename: filename ?? "payload.json",
            dataBase64: Data(json.utf8).base64EncodedString()
        )
    }

    func decodedString() -> String? {
        Data(base64Encoded: dataBase64).flatMap { String(data: $0, encoding: .utf8) }
    }
}

public enum ChatMessageAction: Identifiable, Equatable, Hashable, Codable {
    case copyText
    case copyAttachment(UUID)          // attachmentId
    case sendAttachmentToAI(UUID)      // attachmentId

    public var id: String {
        switch self {
        case .copyText: return "copyText"
        case .copyAttachment(let id): return "copyAttachment:\(id.uuidString)"
        case .sendAttachmentToAI(let id): return "sendToAI:\(id.uuidString)"
        }
    }

    public var title: String {
        switch self {
        case .copyText: return "Copy"
        case .copyAttachment: return "Copy JSON"
        case .sendAttachmentToAI: return "Send it to me"
        }
    }
}

// MARK: - Bridging: Realm -> Model

extension ChatMessage {
    init(from r: ChatMessageLocal) {
        self.id = r.id
        self.conversationId = r.conversationId
        self.role = ChatRole(rawValue: r.roleRaw) ?? .assistant
        self.rawText = r.rawText
        self.format = r.format
        self.richText = nil
        self.createdAt = r.createdAt
        self.status = MessageStatus(rawValue: r.statusRaw) ?? .sent
        self.userId = r.userId
        self.parentId = r.parentId
        self.errorDescription = r.errorDescription

        self.attachments = r.attachments.map { $0.toModel() }
        self.actions = r.actions.compactMap { $0.toModel() }
    }
}

private extension ChatAttachmentLocal {
    func toModel() -> ChatAttachment {
        ChatAttachment(
            id: id,
            mime: mime,
            schema: schema,
            filename: filename,
            dataBase64: dataBase64
        )
    }
}

private extension ChatActionLocal {
    func toModel() -> ChatMessageAction? {
        switch typeRaw {
        case "copyText":
            return .copyText
        case "copyAttachment":
            if let id = attachmentId { return .copyAttachment(id) }
            return nil
        case "sendAttachmentToAI":
            if let id = attachmentId { return .sendAttachmentToAI(id) }
            return nil
        default:
            return nil
        }
    }
}
