//
//  ChatMessageLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation
import RealmSwift

public enum ChatSyncStatus: String, Codable {
    case pending    // Never tried
    case syncing    // Currently uploading
    case synced     // Successfully uploaded
    case failed     // Failed, will retry
    case abandoned  // Too many failures, give up
}

public final class ChatMessageLocal: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted(indexed: true) var conversationId: UUID
    @Persisted var roleRaw: String = "assistant"    // ChatRole.rawValue
    @Persisted var rawText: String = ""
    @Persisted var textData: Data?
    @Persisted var formatRaw: String  // "plain" | "markdown" | "rich"
    @Persisted(indexed: true) var createdAt: Date = Date()
    @Persisted var statusRaw: String = "sent"       // MessageStatus.rawValue
    @Persisted var userId: UUID?
    @Persisted var attachments: List<ChatAttachmentLocal>
    @Persisted var actions: List<String>
    @Persisted var parentId: UUID?
    @Persisted var errorDescription: String?

    // Sync fields
    @Persisted var syncStatusRaw: String = ChatSyncStatus.pending.rawValue
    @Persisted var syncAttempts: Int = 0
    @Persisted var lastSyncError: String?
    @Persisted var updatedAt: Date = Date()
    @Persisted var deletedAt: Date?

    var format: ChatMessageFormat {
        get { ChatMessageFormat(rawValue: formatRaw) ?? .plain }
        set { formatRaw = newValue.rawValue }
    }

    var syncStatus: ChatSyncStatus {
        get { ChatSyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    var attributedText: NSAttributedString? {
        get { textData.flatMap { NSAttributedString.fromData($0) } }
        set { textData = newValue?.toData() }
    }
    
    var richText: AttributedString? {
        get {
            if let attr = attributedText {
                return AttributedString(attr)
            } else {
                return nil
            }
        }
        set {
            if let attr = newValue {
                attributedText = NSAttributedString(attr)
            } else {
                attributedText = nil
            }
        }
    }
}

extension ChatMessageLocal {
    convenience init(domain: ChatMessage) {
        self.init()
        self.id = domain.id
        self.conversationId = domain.conversationId
        self.roleRaw = domain.role.rawValue
        self.rawText = domain.rawText
        self.richText = domain.richText
        self.format = domain.format
        self.createdAt = domain.createdAt
        self.statusRaw = domain.status.rawValue
        self.userId = domain.userId
        self.parentId = domain.parentId
        self.errorDescription = domain.errorDescription
        self.deletedAt = domain.deletedAt
        self.syncStatus = domain.syncStatus

        let atts = domain.attachments.map { ChatAttachmentLocal(domain: $0) }
        self.attachments.append(objectsIn: atts)

        let acts = domain.actions.map { String($0.label.characters) }
        self.actions.append(objectsIn: acts)
    }
}
