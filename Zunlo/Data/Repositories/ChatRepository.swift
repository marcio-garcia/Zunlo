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
    private let store: ChatLocalStore

    init(store: ChatLocalStore) { self.store = store }

    func loadMessages(conversationId: UUID, limit: Int? = 200) async throws -> [ChatMessage] {
        let messages = try await store.fetch(conversationId: conversationId, limit: limit)
        return messages.map { ChatMessage(local: $0) }
    }

    func upsert(_ message: ChatMessage) async throws {
        try await store.upsert(message)
    }

    func appendDelta(messageId: UUID, delta: String, status: ChatMessageStatus) async throws {
        try await store.append(messageId: messageId, delta: delta, status: status)
    }

    func setStatus(messageId: UUID, status: ChatMessageStatus, error: String?) async throws {
        try await store.updateStatus(messageId: messageId, status: status, error: error)
    }

    func delete(messageId: UUID) async throws {
        try await store.delete(messageId: messageId)
    }
    
    func deleteAll(_ conversationId: UUID) async throws {
        try await store.deleteAll(conversationId)
    }
    
    func setFormat(messageId: UUID, format: ChatMessageFormat) async throws {
        try await store.setFormat(messageId: messageId, format: format)
    }
}
