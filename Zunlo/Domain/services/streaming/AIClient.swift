//
//  AIClient.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

// MARK: - AI Streaming Abstractions

import Foundation

public enum AIEvent {
    case started(replyId: UUID)                  // placeholder assistant message created
    case delta(replyId: UUID, text: String)      // streaming token(s)
    case toolCall(name: String, argumentsJSON: String)
    case suggestions([String])                   // quick-reply chips
    case completed(replyId: UUID)
}

public protocol AIClient {
    func generate(
        conversationId: UUID,
        history: [ChatMessage],
        userInput: String,
        attachments: [ChatAttachment],
        supportsTools: Bool
    ) -> AsyncThrowingStream<AIEvent, Error>

    func cancelCurrentGeneration()
}
