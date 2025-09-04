//
//  ChatEngineEvent.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/4/25.
//

import Foundation

public enum ChatEngineEvent {
    case messageAppended(ChatMessage)                 // new message persisted/emitted (user/assistant/tool)
    case messageDelta(messageId: UUID, delta: String) // assistant token delta
    case messageStatusUpdated(messageId: UUID, status: ChatMessageStatus, error: String?)
    case messageFormatUpdated(messageId: UUID, format: ChatMessageFormat)
    case suggestions([String])
    case responseCreated(String)
    case stateChanged(ChatStreamState)
    case completed(messageId: UUID)
}
