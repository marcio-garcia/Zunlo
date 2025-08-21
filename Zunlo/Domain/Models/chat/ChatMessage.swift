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

public struct ChatMessage: Identifiable, Hashable, Codable {
    public let id: UUID
    public let conversationId: UUID
    public let role: ChatRole
    public var text: String
    public let createdAt: Date
    public var status: MessageStatus
    public var userId: UUID?
    public var attachments: [ChatAttachment]
    public var actions: [ChatMessageAction] = []
    public var parentId: UUID?
    public var errorDescription: String?

    public init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: ChatRole,
        text: String,
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
        self.text = text
        self.createdAt = createdAt
        self.status = status
        self.userId = userId
        self.attachments = attachments
        self.parentId = parentId
        self.errorDescription = errorDescription
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
        self.text = r.text
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
