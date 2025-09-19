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

    func fetch(conversationId: UUID, limit: Int?) async throws -> [ChatMessageLocal] {
        try await db.fetchChatMessages(conversationId: conversationId, limit: limit)
    }

    func upsert(_ message: ChatMessage) async throws {
        try await db.upsertChatMessage(message)
    }

    func append(messageId: UUID, delta: String, status: ChatMessageStatus) async throws {
        try await db.appendChatMessage(messageId: messageId, delta: delta, status: status)
    }

    func updateStatus(messageId: UUID, status: ChatMessageStatus, error: String?) async throws {
        try await db.updateChatMessageStatus(messageId: messageId, status: status, error: error)
    }

    func delete(messageId: UUID) async throws {
        try await db.deleteChatMessage(messageId: messageId)
    }
    
    func deleteAll(_ conversationId: UUID) async throws {
        try await db.deleteAllChatMessages(conversationId)
    }
    
    func setFormat(messageId: UUID, format: ChatMessageFormat) async throws {
        try await db.setFormat(messageId: messageId, format: format)
    }
}
