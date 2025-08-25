//
//  InMemoryChatRepositoryActor.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/21/25.
//

// MARK: - Lightweight fakes for domain

import Foundation
@testable import Zunlo

public actor InMemoryChatRepositoryActor: ChatRepository {
    // We shadow the API of ChatRepositoryActor used by ChatEngine
    private var messages: [UUID: ChatMessage] = [:]
    public init() {}
    public func loadMessages(conversationId: UUID, limit: Int?) async throws -> [ChatMessage] { messages.values.sorted { $0.createdAt < $1.createdAt } }
    public func upsert(_ message: ChatMessage) async throws { messages[message.id] = message }
    public func appendDelta(messageId: UUID, delta: String, status: ChatMessageStatus) async throws {
        var m = messages[messageId] ?? ChatMessage(id: messageId, conversationId: UUID(), role: .assistant, plain: "", createdAt: Date(), status: .streaming)
        m.rawText += delta
        m.status = status
        messages[messageId] = m
    }
    public func setStatus(messageId: UUID, status: ChatMessageStatus, error: String?) async throws {
        guard var m = messages[messageId] else { return }
        m.status = status
        m.errorDescription = error
        messages[messageId] = m
    }
    public func delete(messageId: UUID) async throws { messages.removeValue(forKey: messageId) }
    public func deleteAll(_ conversationId: UUID) async throws { messages.removeAll() }
    public func setFormat(messageId: UUID, format: Zunlo.ChatMessageFormat) async throws {
        messages[messageId]?.format = format
    }

}


public struct DummyToolResult { let note: String; let ui: ChatInsert? }


public final class MockToolRouter: ToolRouter {
    public init() {}
    
    public func dispatch(_ env: AIToolEnvelope) async throws -> ToolDispatchResult {
        if env.name == "echo" {
            return ToolDispatchResult(note: "echo: \(env.argsJSON)", ui: nil)
        }
        return ToolDispatchResult(note: "ran_\(env.name)", ui: nil)
    }
}
