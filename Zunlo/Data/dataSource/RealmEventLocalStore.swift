//
//  RealmEventLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/7/25.
//

import Foundation
import RealmSwift

final class RealmEventLocalStore: EventLocalStore {

    func fetchAll() async throws -> [Event] {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let eventsLocal = Array(realm.objects(EventLocal.self).sorted(byKeyPath: "startDate", ascending: true))
            return eventsLocal.map { Event(local: $0) }
        }.value
    }

    func save(_ remoteEvent: EventRemote) async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let event = EventLocal(remote: remoteEvent)
            try realm.write {
                realm.add(event, update: .all)
            }
        }.value
    }

    func update(_ event: EventRemote) async throws {
        // The safest: update by ID, copy fields over
        let eventID = event.id
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            guard let existing = realm.object(ofType: EventLocal.self, forPrimaryKey: eventID) else { return }
            try realm.write {
                existing.getUpdateFields(event)
            }
        }.value
    }

    func delete(id: UUID) async throws {
        let eventID = id
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            guard let existing = realm.object(ofType: EventLocal.self, forPrimaryKey: eventID) else { return }
            try realm.write {
                realm.delete(existing)
            }
        }.value
    }

    func deleteAll(for userId: UUID) async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let events = realm.objects(EventLocal.self).filter("userId == %@", userId)
            try realm.write {
                realm.delete(events)
            }
        }.value
    }
    
    func deleteAll() async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            try realm.write {
                realm.delete(realm.objects(EventLocal.self))
            }
        }.value
    }
}
