//
//  MessagePersistence.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/22/25.
//

import Foundation

/// Handles message persistence with debounced delta buffering
actor MessagePersistence {
    private let repo: ChatRepository
    private var deltaBuffers: [UUID: String] = [:]
    private var deltaFlushTasks: [UUID: Task<Void, Never>] = [:]
    private let deltaFlushNs: UInt64 = 150_000_000 // 150ms

    init(repo: ChatRepository) {
        self.repo = repo
    }

    func upsert(_ message: ChatMessage) async throws {
        try await repo.upsert(message)
    }

    func setStatus(messageId: UUID, status: ChatMessageStatus, error: String?) async throws {
        try await repo.setStatus(messageId: messageId, status: status, error: error)
    }

    func setFormat(messageId: UUID, format: ChatMessageFormat) async throws {
        try await repo.setFormat(messageId: messageId, format: format)
    }

    func delete(messageId: UUID) async throws {
        try await repo.delete(messageId: messageId)
    }

    func loadMessages(conversationId: UUID, limit: Int?) async throws -> [ChatMessage] {
        try await repo.loadMessages(conversationId: conversationId, limit: limit)
    }

    func bufferDelta(id: UUID, delta: String) async {
        deltaBuffers[id, default: ""].append(delta)
        if deltaFlushTasks[id] == nil {
            deltaFlushTasks[id] = Task { [weak self] in
                try? await Task.sleep(nanoseconds: self?.deltaFlushNs ?? 150_000_000)
                await self?.flushDeltaNow(id)
            }
        }
    }

    func flushDeltaNow(_ id: UUID) async {
        deltaFlushTasks[id]?.cancel()
        deltaFlushTasks[id] = nil
        guard let buf = deltaBuffers[id], !buf.isEmpty else {
            deltaBuffers[id] = nil
            return
        }
        deltaBuffers[id] = ""
        try? await repo.appendDelta(messageId: id, delta: buf, status: .streaming)
    }
}