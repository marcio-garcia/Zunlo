//
//  AIChatService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

// MARK: - AI Streaming Abstractions

import Foundation

public enum AIEvent {
    case started(replyId: UUID)                  // placeholder assistant message created
    case responseCreated(responseId: String)
    case delta(replyId: UUID, text: String)      // streaming token(s)
    case toolCall(name: String, argumentsJSON: String)
    case toolBatch([ToolCallRequest]) // <-- batch, not one-by-one
    case suggestions([String])                   // quick-reply chips
    case completed(replyId: UUID)
}

public protocol AIChatService {
    func generate(
        conversationId: UUID,
        history: [ChatMessage],
        output: [ToolOutput],
        supportsTools: Bool
    ) throws -> AsyncThrowingStream<AIEvent, Error>

    func cancelCurrentGeneration()
    func submitToolOutputs(responseId: String, outputs: [ToolOutput]) async throws
}
