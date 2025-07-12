//
//  RealmChatLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation
import RealmSwift

final class RealmChatLocalStore: ChatLocalStore {
    func fetchAll() async throws -> [ChatMessage] {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let localMessages = realm.objects(ChatMessageLocal.self).sorted(byKeyPath: "createdAt", ascending: true)
            return localMessages.map { ChatMessage(local: $0) }
        }.value
    }

    func save(_ message: ChatMessage) async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let local = ChatMessageLocal(
                id: message.id,
                userId: message.userId,
                message: message.message,
                createdAt: message.createdAt,
                isFromUser: message.isFromUser
            )
            try realm.write {
                realm.add(local, update: .all)
            }
        }.value
    }

    func deleteAll() async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            try realm.write {
                realm.delete(realm.objects(ChatMessageLocal.self))
            }
        }.value
    }
}
