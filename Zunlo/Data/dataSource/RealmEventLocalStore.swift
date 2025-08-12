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

extension RealmEventLocalStore {
    // MARK: - Aggregated local fetch that mirrors the remote payload

    func fetchOccurrences(for userId: UUID) async throws -> [EventOccurrenceResponse] {
        try await Task.detached(priority: .background) {
            let realm = try Realm()

            // 1) Events (optionally filter by user), ordered like the server
            var eventsResults = realm.objects(EventLocal.self)
            eventsResults = eventsResults.where { $0.userId == userId }

            eventsResults = eventsResults
                .sorted(byKeyPath: "startDate", ascending: true)
                .sorted(byKeyPath: "id", ascending: true) // tie-breaker

            let eventLocals = Array(eventsResults)
            guard !eventLocals.isEmpty else { return [] }

            // Collect IDs once
            let eventIds = eventLocals.map(\.id)

            // 2) Bulk fetch children to avoid N+1; pre-sorted by id to match SQL
            let overridesLocals = Array(
                realm.objects(EventOverrideLocal.self)
                    .where { $0.eventId.in(eventIds) }
                    .sorted(byKeyPath: "id", ascending: true)
            )
            let rulesLocals = Array(
                realm.objects(RecurrenceRuleLocal.self)
                    .where { $0.eventId.in(eventIds) }
                    .sorted(byKeyPath: "id", ascending: true)
            )

            // 3) Group children by eventId
            let overridesByEvent = Dictionary(grouping: overridesLocals, by: \.eventId)
            let rulesByEvent     = Dictionary(grouping: rulesLocals,     by: \.eventId)

            // 4) Build the remote-shaped DTOs in order
            let result: [EventOccurrenceResponse] = eventLocals.map { e in
                let ovs = overridesByEvent[e.id] ?? []
                let rrs = rulesByEvent[e.id] ?? []
                return EventOccurrenceResponse(local: e, overrides: ovs, rules: rrs)
            }

            return result
        }.value
    }
}
