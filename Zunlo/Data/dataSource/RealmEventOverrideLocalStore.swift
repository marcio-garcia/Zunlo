//
//  RealmEventOverrideLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/7/25.
//

import Foundation
import RealmSwift

final class RealmEventOverrideLocalStore: EventOverrideLocalStore {
    // Async fetch all
    func fetchAll() async throws -> [EventOverride] {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let overridesLocal = Array(realm.objects(EventOverrideLocal.self))
            return overridesLocal.map { EventOverride(local: $0) }
        }.value
    }

    // Async fetch by eventId
    func fetch(for eventId: UUID) async throws -> [EventOverride] {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let results = realm.objects(EventOverrideLocal.self).where { $0.eventId == eventId }
            let overridesLocal = Array(results)
            return overridesLocal.map { EventOverride(local: $0) }
        }.value
    }

    // Async save (new or update)
    func save(_ overrideRemote: EventOverrideRemote) async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let override = EventOverrideLocal(remote: overrideRemote)
            try realm.write {
                realm.add(override, update: .all)
            }
        }.value
    }
    
    // Async update by ID and value
    func update(_ overrideRemote: EventOverrideRemote) async throws {
        let overrideID = overrideRemote.id
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            guard let existing = realm.object(ofType: EventOverrideLocal.self, forPrimaryKey: overrideID) else { return }
            try realm.write {
                existing.getUpdateFields(overrideRemote)
            }
        }.value
    }

    // Async delete by ID
    func delete(id: UUID) async throws {
        let overrideID = id
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            guard let existing = realm.object(ofType: EventOverrideLocal.self, forPrimaryKey: overrideID) else { return }
            try realm.write {
                realm.delete(existing)
            }
        }.value
    }
    
    // Async delete all
    func deleteAll() async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let all = realm.objects(EventOverrideLocal.self)
            try realm.write {
                realm.delete(all)
            }
        }.value
    }
}
