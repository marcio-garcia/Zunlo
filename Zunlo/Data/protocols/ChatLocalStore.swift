//
//  ChatLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation

protocol ChatLocalStore {
    func fetch(conversationId: UUID, userId: UUID, limit: Int?) async throws -> [ChatMessageLocal]
    func upsert(_ message: ChatMessage) async throws
    func append(messageId: UUID, delta: String, status: ChatMessageStatus, userId: UUID) async throws
    func updateStatus(messageId: UUID, status: ChatMessageStatus, error: String?, userId: UUID) async throws
    func delete(messageId: UUID, userId: UUID) async throws
    func softDelete(messageId: UUID, userId: UUID) async throws
    func deleteAll(_ conversationId: UUID, userId: UUID) async throws
    func setFormat(messageId: UUID, format: ChatMessageFormat, userId: UUID) async throws
}
