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

public struct ChatAttachment: Codable, Hashable {
    public enum Kind: String, Codable { case event, task }
    public let kind: Kind
    public let id: UUID

    public init(kind: Kind, id: UUID) {
        self.kind = kind
        self.id = id
    }
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
