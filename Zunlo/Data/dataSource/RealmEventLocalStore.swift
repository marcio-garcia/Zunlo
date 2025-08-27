//
//  RealmEventLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/7/25.
//

import Foundation

final class RealmEventLocalStore: EventLocalStore {
    private let db: DatabaseActor
    
    init(db: DatabaseActor) {
        self.db = db
    }
    
    func fetchAll() async throws -> [EventLocal] {
        try await db.fetchAllEventsSorted()
    }
    
    func fetch(id: UUID) async throws -> EventLocal? {
        try await db.fetchEvent(id: id)
    }
    
    func fetch(userId: UUID, startAt: Date) async throws -> EventLocal? {
        let filter = EventFilter(userId: userId, startDateRange: startAt...startAt)
        let events = try await db.fetchEvents(filteredBy: filter)
        if let event = events.first {
            return event
        }
        return nil
    }
    
    func fetch(filteredBy filter: EventFilter) async throws -> [EventLocal] {
        return try await db.fetchEvents(filteredBy: filter)
    }

    func upsert(_ event: EventRemote) async throws {
        try await db.upsertEvent(from: event)
    }

    func upsert(_ event: EventLocal) async throws {
        try await db.upsertEvent(from: event)
    }
    
    func upsert(event: EventLocal, rule: RecurrenceRule) async throws {
        try await db.upsertEvent(local: event, rule: rule)
    }

    func delete(id: UUID) async throws {
        try await db.softDeleteEvent(id: id)
    }

    func deleteAll(for userId: UUID) async throws {
        try await db.deleteAllEvents(for: userId)
    }

    func deleteAll() async throws {
        try await db.deleteAllEvents()
    }
    
    func apply(rows: [EventRemote]) async throws {
        try await db.applyRemoteEvents(rows)
    }
}

extension RealmEventLocalStore {
    func fetchOccurrences(for userId: UUID) async throws -> [EventOccurrenceResponse] {
        return try await db.fetchOccurrences(userId: userId)
    }
    
    func splitRecurringEvent(
        originalEventId: UUID,
        splitDate: Date,
        newEvent: EventLocal
    ) async throws -> UUID {
        return try await db.splitRecurringEventFrom(
            originalEventId: originalEventId,
            splitDate: splitDate,
            newEvent: newEvent
        )
    }
}
