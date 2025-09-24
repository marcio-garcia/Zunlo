//
//  RealmChatLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation

// Realm-backed implementation using your DatabaseActor methods.
final class RealmChatLocalStore: ChatLocalStore {
    
    private let db: DatabaseActor
    
    init(db: DatabaseActor) { self.db = db }

    func fetch(conversationId: UUID, userId: UUID, limit: Int?) async throws -> [ChatMessageLocal] {
        try await db.fetchChatMessages(conversationId: conversationId, userId: userId, limit: limit)
    }

    func upsert(_ message: ChatMessage) async throws {
        try await db.upsertChatMessage(message)
    }

    func append(messageId: UUID, delta: String, status: ChatMessageStatus, userId: UUID) async throws {
        try await db.appendChatMessage(messageId: messageId, delta: delta, status: status, userId: userId)
    }

    func updateStatus(messageId: UUID, status: ChatMessageStatus, error: String?, userId: UUID) async throws {
        try await db.updateChatMessageStatus(messageId: messageId, status: status, error: error, userId: userId)
    }

    func delete(messageId: UUID, userId: UUID) async throws {
        try await db.deleteChatMessage(messageId: messageId, userId: userId)
    }
    
    func deleteAll(_ conversationId: UUID, userId: UUID) async throws {
        try await db.deleteAllChatMessages(conversationId, userId: userId)
    }
    
    func setFormat(messageId: UUID, format: ChatMessageFormat, userId: UUID) async throws {
        try await db.setFormat(messageId: messageId, format: format, userId: userId)
    }
}
