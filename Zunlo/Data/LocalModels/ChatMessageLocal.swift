//
//  ChatMessageLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation
import RealmSwift

final class ChatAttachmentEmbedded: EmbeddedObject {
    @Persisted var json: String = "{}"
    @Persisted var id: UUID = UUID()
}

final class ChatMessageLocal: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted(indexed: true) var conversationId: UUID
    @Persisted var roleRaw: String = "assistant"    // ChatRole.rawValue
    @Persisted var rawText: String = ""
    @Persisted var formatRaw: String  // "plain" | "markdown" | "rich"
    @Persisted(indexed: true) var createdAt: Date = Date()
    @Persisted var statusRaw: String = "sent"       // MessageStatus.rawValue
    @Persisted var userId: UUID?
    @Persisted var attachments: List<ChatAttachmentLocal>
    @Persisted var actions: List<ChatActionLocal>
    @Persisted var parentId: UUID?
    @Persisted var errorDescription: String?
    
    var format: ChatMessageFormat {
        get { ChatMessageFormat(rawValue: formatRaw) ?? .plain }
        set { formatRaw = newValue.rawValue }
    }
}

final class ChatAttachmentLocal: EmbeddedObject {
    @Persisted var id: UUID
    @Persisted var mime: String
    @Persisted var schema: String?
    @Persisted var filename: String?
    @Persisted var dataBase64: String
}

final class ChatActionLocal: EmbeddedObject {
    @Persisted var typeRaw: String   // "copyText" | "copyAttachment" | "sendAttachmentToAI"
    @Persisted var attachmentId: UUID?
}


extension ChatMessageLocal {
    convenience init(from m: ChatMessage) {
        self.init()
        self.id = m.id
        self.conversationId = m.conversationId
        self.roleRaw = m.role.rawValue
        self.rawText = m.rawText
        self.format = m.format
        self.createdAt = m.createdAt
        self.statusRaw = m.status.rawValue
        self.userId = m.userId
        self.parentId = m.parentId
        self.errorDescription = m.errorDescription

        let atts = m.attachments.map(ChatAttachmentLocal.init(from:))
        self.attachments.append(objectsIn: atts)

        let acts = m.actions.map(ChatActionLocal.init(from:))
        self.actions.append(objectsIn: acts)
    }
}

private extension ChatAttachmentLocal {
    convenience init(from a: ChatAttachment) {
        self.init()
        self.id = a.id
        self.mime = a.mime
        self.schema = a.schema
        self.filename = a.filename
        self.dataBase64 = a.dataBase64
    }
}

private extension ChatActionLocal {
    convenience init(from a: ChatMessageAction) {
        self.init()
        switch a {
        case .copyText:
            self.typeRaw = "copyText"
            self.attachmentId = nil
        case .copyAttachment(let id):
            self.typeRaw = "copyAttachment"
            self.attachmentId = id
        case .sendAttachmentToAI(let id):
            self.typeRaw = "sendAttachmentToAI"
            self.attachmentId = id
        }
    }
}
