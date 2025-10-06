//
//  ChatMessageRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 1/5/25.
//

import Foundation

public struct ChatMessageRemote: RemoteEntity, Codable, Identifiable {
    public var id: UUID
    public var conversationId: UUID
    public var userId: UUID
    public var role: String
    public var rawText: String
    public var format: String
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedAtRaw: String?
    public var deletedAt: Date?
    public var parentId: UUID?

    public init(
        id: UUID,
        conversationId: UUID,
        userId: UUID,
        role: String,
        rawText: String,
        format: String,
        createdAt: Date,
        updatedAt: Date,
        updatedAtRaw: String? = nil,
        deletedAt: Date? = nil,
        parentId: UUID? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.userId = userId
        self.role = role
        self.rawText = rawText
        self.format = format
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.updatedAtRaw = updatedAtRaw
        self.deletedAt = deletedAt
        self.parentId = parentId
    }

    // RemoteEntity conformance (version not needed for chat)
    public var version: Int? { nil }
}

// MARK: - Conversions

extension ChatMessageRemote {
    init(local: ChatMessageLocal) {
        self.id = local.id
        self.conversationId = local.conversationId
        self.userId = local.userId ?? UUID()
        self.role = local.roleRaw
        self.rawText = local.rawText
        self.format = local.formatRaw
        self.createdAt = local.createdAt
        self.updatedAt = local.updatedAt
        self.updatedAtRaw = ""
        self.deletedAt = local.deletedAt
        self.parentId = local.parentId
    }

    func toDomain() -> ChatMessage {
        ChatMessage(
            id: id,
            conversationId: conversationId,
            role: ChatRole(rawValue: role) ?? .assistant,
            plain: rawText,
            createdAt: createdAt,
            status: .sent,
            userId: userId,
            parentId: parentId,
            deletedAt: deletedAt,
            syncStatus: .synced  // Messages from server are already synced
        )
    }
}

// MARK: - Codable

extension ChatMessageRemote {
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case role
        case rawText = "raw_text"
        case format
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case parentId = "parent_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decode(UUID.self, forKey: .id)
        conversationId = try c.decode(UUID.self, forKey: .conversationId)
        userId = try c.decode(UUID.self, forKey: .userId)
        role = try c.decode(String.self, forKey: .role)
        rawText = try c.decode(String.self, forKey: .rawText)
        format = try c.decode(String.self, forKey: .format)
        parentId = try c.decodeIfPresent(UUID.self, forKey: .parentId)

        // Parse timestamps
        let createdAtRaw = try c.decode(String.self, forKey: .createdAt)
        guard let parsedCreatedAt = RFC3339MicrosUTC.parse(createdAtRaw) else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: c, debugDescription: "Invalid created_at: \(createdAtRaw)")
        }
        createdAt = parsedCreatedAt

        let updatedAtRawValue = try c.decode(String.self, forKey: .updatedAt)
        updatedAtRaw = updatedAtRawValue
        guard let parsedUpdatedAt = RFC3339MicrosUTC.parse(updatedAtRawValue) else {
            throw DecodingError.dataCorruptedError(forKey: .updatedAt, in: c, debugDescription: "Invalid updated_at: \(updatedAtRawValue)")
        }
        updatedAt = parsedUpdatedAt

        if let deletedAtRaw = try c.decodeIfPresent(String.self, forKey: .deletedAt) {
            guard let parsed = RFC3339MicrosUTC.parse(deletedAtRaw) else {
                throw DecodingError.dataCorruptedError(forKey: .deletedAt, in: c, debugDescription: "Invalid deleted_at: \(deletedAtRaw)")
            }
            deletedAt = parsed
        } else {
            deletedAt = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        try c.encode(id, forKey: .id)
        try c.encode(conversationId, forKey: .conversationId)
        try c.encode(userId, forKey: .userId)
        try c.encode(role, forKey: .role)
        try c.encode(rawText, forKey: .rawText)
        try c.encode(format, forKey: .format)
        try c.encodeIfPresent(parentId, forKey: .parentId)

        // Encode timestamps (server owns these, but we include them for consistency)
        try c.encode(RFC3339MicrosUTC.string(createdAt), forKey: .createdAt)
        try c.encode(RFC3339MicrosUTC.string(updatedAt), forKey: .updatedAt)
        try c.encodeIfPresent(deletedAt.map(RFC3339MicrosUTC.string), forKey: .deletedAt)
    }
}
