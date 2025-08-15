//
//  ChatMessageLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation
import RealmSwift

final class ChatAttachmentEmbedded: EmbeddedObject {
    @Persisted var kindRaw: String = "task"   // "task" | "event"
    @Persisted var id: UUID = UUID()
}

final class ChatMessageLocal: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted(indexed: true) var conversationId: UUID
    @Persisted var roleRaw: String = "assistant"    // ChatRole.rawValue
    @Persisted var text: String = ""
    @Persisted(indexed: true) var createdAt: Date = Date()
    @Persisted var statusRaw: String = "sent"       // MessageStatus.rawValue
    @Persisted var userId: UUID?
    @Persisted var attachments: List<ChatAttachmentEmbedded>
    @Persisted var parentId: UUID?
    @Persisted var errorDescription: String?
}
