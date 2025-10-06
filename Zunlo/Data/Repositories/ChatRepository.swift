//
//  ChatRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation

// How chat simple sync works
//
// On Send:
// 1. Message saved locally with syncStatus = .pending
// 2. Fire-and-forget task attempts POST to Supabase
// 3. Success → syncStatus = .synced
// 4. Failure → syncStatus = .failed, retry on next sync
//
// On Sync (app launch/foreground):
// 1. Push all pending/failed messages (up to 5 attempts each)
// 2. Pull new messages from server using cursor
// 3. Merge into local DB (skip duplicates)
// 4. Update cursor for next sync
//
// The system is much simpler than full version tracking because:
// - No updates/conflicts (messages are immutable)
// - No complex merge logic
// - Just insert + retry

protocol ChatRepository {
    func loadMessages(conversationId: UUID, limit: Int?) async throws -> [ChatMessage]
    func upsert(_ message: ChatMessage) async throws
    func appendDelta(messageId: UUID, delta: String, status: ChatMessageStatus) async throws
    func setStatus(messageId: UUID, status: ChatMessageStatus, error: String?) async throws
    func delete(messageId: UUID) async throws
    func deleteAll(_ conversationId: UUID) async throws
    func setFormat(messageId: UUID, format: ChatMessageFormat) async throws
}

final class DefaultChatRepository: ChatRepository {
    private let auth: AuthProviding
    private let store: ChatLocalStore
    private let syncEngine: ChatSyncEngine?

    init(auth: AuthProviding, store: ChatLocalStore, syncEngine: ChatSyncEngine?) {
        self.auth = auth
        self.store = store
        self.syncEngine = syncEngine
    }

    func loadMessages(conversationId: UUID, limit: Int? = 200) async throws -> [ChatMessage] {
        guard try await auth.isAuthorized(), let userId = await auth.userId else { return [] }
        let messages = try await store.fetch(conversationId: conversationId, userId: userId, limit: limit)
        return messages.map { ChatMessage(local: $0) }
    }

    func upsert(_ message: ChatMessage) async throws {
        guard try await auth.isAuthorized(), let userId = await auth.userId else { return }
        var messageWithUserId = message
        messageWithUserId.userId = userId
        try await store.upsert(messageWithUserId)

        // Fire-and-forget: try to sync immediately
        if let syncEngine = syncEngine {
            Task.detached(priority: .utility) {
                await syncEngine.trySyncMessage(messageWithUserId.id)
            }
        }
    }

    func appendDelta(messageId: UUID, delta: String, status: ChatMessageStatus) async throws {
        guard try await auth.isAuthorized(), let userId = await auth.userId else { return }
        try await store.append(messageId: messageId, delta: delta, status: status, userId: userId)
    }

    func setStatus(messageId: UUID, status: ChatMessageStatus, error: String?) async throws {
        guard try await auth.isAuthorized(), let userId = await auth.userId else { return }
        try await store.updateStatus(messageId: messageId, status: status, error: error, userId: userId)
    }

    func delete(messageId: UUID) async throws {
        guard try await auth.isAuthorized(), let userId = await auth.userId else { return }
        // Soft-delete instead of hard delete to enable sync
        try await store.softDelete(messageId: messageId, userId: userId)

        // Fire-and-forget: try to sync the deletion immediately
        if let syncEngine = syncEngine {
            Task.detached(priority: .utility) {
                await syncEngine.trySyncMessage(messageId)
            }
        }
    }
    
    func deleteAll(_ conversationId: UUID) async throws {
        guard try await auth.isAuthorized(), let userId = await auth.userId else { return }
        try await store.deleteAll(conversationId, userId: userId)
    }
    
    func setFormat(messageId: UUID, format: ChatMessageFormat) async throws {
        guard try await auth.isAuthorized(), let userId = await auth.userId else { return }
        try await store.setFormat(messageId: messageId, format: format, userId: userId)
    }
}
