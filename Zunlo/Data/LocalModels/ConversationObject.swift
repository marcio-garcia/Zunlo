//
//  ConversationObject.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

import Foundation
import RealmSwift

// MARK: - Conversation Realm model

final public class ConversationObject: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted(indexed: true) var createdAt: Date = Date()
    @Persisted(indexed: true) var updatedAt: Date = Date()
    @Persisted var title: String?                   // e.g., "Chat"
    @Persisted(indexed: true) var archived: Bool = false
    @Persisted(indexed: true) var kindRaw: String = "general" // keep "general" for single thread
    @Persisted var metadata: Data?                  // optional JSON blob
    // Nice-to-haves for a future conversation list:
    @Persisted var lastMessagePreview: String?
    @Persisted(indexed: true) var lastMessageAt: Date?
    @Persisted var draftInput: String?              // store per-convo input draft if you want
}
