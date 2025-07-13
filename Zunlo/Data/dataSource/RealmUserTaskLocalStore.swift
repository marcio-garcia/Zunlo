//
//  RealmUserTaskLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation
import RealmSwift

final class RealmUserTaskLocalStore: UserTaskLocalStore {

    func fetchAll() async throws -> [UserTask] {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let eventsLocal = Array(realm.objects(UserTaskLocal.self).sorted(byKeyPath: "startDate", ascending: true))
            return eventsLocal.map { $0.toDomain() }
        }.value
    }

    func save(_ remote: UserTaskRemote) async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let local = UserTaskLocal(from: remote)
            try realm.write {
                realm.add(local, update: .all)
            }
        }.value
    }

    func update(_ remote: UserTaskRemote) async throws {
        // The safest: update by ID, copy fields over
        let id = remote.id
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            guard let existing = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: id) else { return }
            try realm.write {
                existing.getUpdateFields(remote: remote)
            }
        }.value
    }

    func delete(id: UUID) async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            guard let existing = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: id) else { return }
            try realm.write {
                realm.delete(existing)
            }
        }.value
    }

    func deleteAll(for userId: UUID) async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let events = realm.objects(UserTaskLocal.self).filter("userId == %@", userId)
            try realm.write {
                realm.delete(events)
            }
        }.value
    }
    
    func deleteAll() async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            try realm.write {
                realm.delete(realm.objects(UserTaskLocal.self))
            }
        }.value
    }
}

