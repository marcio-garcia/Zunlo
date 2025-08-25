//
//  RealmChatLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation

// Realm-backed implementation using your DatabaseActor methods.
public final class RealmChatLocalStore: ChatLocalStore {
    
    private let db: DatabaseActor
    
    public init(db: DatabaseActor) { self.db = db }

    public func fetch(conversationId: UUID, limit: Int?) async throws -> [ChatMessageLocal] {
        try await db.fetchChatMessages(conversationId: conversationId, limit: limit)
    }

    public func upsert(_ message: ChatMessage) async throws {
        try await db.upsertChatMessage(message)
    }

    public func append(messageId: UUID, delta: String, status: ChatMessageStatus) async throws {
        try await db.appendChatMessage(messageId: messageId, delta: delta, status: status)
    }

    public func updateStatus(messageId: UUID, status: ChatMessageStatus, error: String?) async throws {
        try await db.updateChatMessageStatus(messageId: messageId, status: status, error: error)
    }

    public func delete(messageId: UUID) async throws {
        try await db.deleteChatMessage(messageId: messageId)
    }
    
    public func deleteAll(_ conversationId: UUID) async throws {
        try await db.deleteAllChatMessages(conversationId)
    }
    
    public func setFormat(messageId: UUID, format: ChatMessageFormat) async throws {
        try await db.setFormat(messageId: messageId, format: format)
    }
}
