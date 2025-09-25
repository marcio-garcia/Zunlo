//
//  ChatRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation

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

    init(auth: AuthProviding, store: ChatLocalStore) {
        self.auth = auth
        self.store = store
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
        try await store.delete(messageId: messageId, userId: userId)
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
