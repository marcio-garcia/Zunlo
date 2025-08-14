//
//  RealmChatLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation
import RealmSwift

final class RealmChatLocalStore: ChatLocalStore {
    private let db: DatabaseActor
    init(db: DatabaseActor) { self.db = db }

    func fetchAll() async throws -> [ChatMessage] {
        try await db.fetchAllChatMessages()
    }

    func save(_ message: ChatMessage) async throws {
        try await db.saveChatMessage(message)
    }

    func deleteAll() async throws {
        try await db.deleteAllChatMessages()
    }
}
