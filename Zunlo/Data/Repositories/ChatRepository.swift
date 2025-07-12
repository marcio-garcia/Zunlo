//
//  ChatRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation

protocol ChatRepository {
    func loadMessages() async throws -> [ChatMessage]
    func sendMessage(_ message: String, fromUser: Bool) async throws
    func clearChat() async throws
}

final class DefaultChatRepository: ChatRepository {
    private let store: ChatLocalStore
    private let userId: UUID?

    init(store: ChatLocalStore, userId: UUID? = nil) {
        self.store = store
        self.userId = userId
    }

    func loadMessages() async throws -> [ChatMessage] {
        try await store.fetchAll()
    }

    func sendMessage(_ message: String, fromUser: Bool) async throws {
        let newMessage = ChatMessage(
            id: UUID(),
            userId: userId,
            message: message,
            createdAt: Date(),
            isFromUser: fromUser
        )
        try await store.save(newMessage)
    }

    func clearChat() async throws {
        try await store.deleteAll()
    }
}

