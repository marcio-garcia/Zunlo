//
//  ChatLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation

public protocol ChatLocalStore {
    func fetch(conversationId: UUID, limit: Int?) async throws -> [ChatMessage]
    func upsert(_ message: ChatMessage) async throws
    func append(messageId: UUID, delta: String, status: ChatMessageStatus) async throws
    func updateStatus(messageId: UUID, status: ChatMessageStatus, error: String?) async throws
    func delete(messageId: UUID) async throws
    func deleteAll(_ conversationId: UUID) async throws
}
