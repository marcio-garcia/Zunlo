//
//  ChatMessageOpPayload.swift
//  Zunlo
//
//  Created by Marcio Garcia on 1/5/25.
//

import Foundation

// MARK: - Chat message payloads (server owns created_at/updated_at)
public struct ChatMessageInsertPayload: Encodable {
    let id: UUID
    let conversation_id: UUID
    let user_id: UUID
    let role: String
    let raw_text: String
    let format: String
    let parent_id: UUID?
    let deleted_at: String?

    init(remote r: ChatMessageRemote) {
        id = r.id
        conversation_id = r.conversationId
        user_id = r.userId
        role = r.role
        raw_text = r.rawText
        format = r.format
        parent_id = r.parentId
        deleted_at = r.deletedAt.map(RFC3339MicrosUTC.string)
    }
}
