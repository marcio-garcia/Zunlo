//
//  ChatRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation

public protocol ChatRepository {
    func loadMessages(conversationId: UUID, limit: Int?) async throws -> [ChatMessage]
    func upsert(_ message: ChatMessage) async throws
    func appendDelta(messageId: UUID, delta: String, status: ChatMessageStatus) async throws
    func setStatus(messageId: UUID, status: ChatMessageStatus, error: String?) async throws
    func delete(messageId: UUID) async throws
    func deleteAll(_ conversationId: UUID) async throws
    func setFormat(messageId: UUID, format: ChatMessageFormat) async throws
}

public final class DefaultChatRepository: ChatRepository {
    private let store: ChatLocalStore

    public init(store: ChatLocalStore) { self.store = store }

    public func loadMessages(conversationId: UUID, limit: Int? = 200) async throws -> [ChatMessage] {
        let messages = try await store.fetch(conversationId: conversationId, limit: limit)
        return messages.map { ChatMessage(from: $0) }
    }

    public func upsert(_ message: ChatMessage) async throws {
        try await store.upsert(message)
    }

    public func appendDelta(messageId: UUID, delta: String, status: ChatMessageStatus) async throws {
        try await store.append(messageId: messageId, delta: delta, status: status)
    }

    public func setStatus(messageId: UUID, status: ChatMessageStatus, error: String?) async throws {
        try await store.updateStatus(messageId: messageId, status: status, error: error)
    }

    public func delete(messageId: UUID) async throws {
        try await store.delete(messageId: messageId)
    }
    
    public func deleteAll(_ conversationId: UUID) async throws {
        try await store.deleteAll(conversationId)
    }
    
    public func setFormat(messageId: UUID, format: ChatMessageFormat) async throws {
        try await store.setFormat(messageId: messageId, format: format)
    }
}
