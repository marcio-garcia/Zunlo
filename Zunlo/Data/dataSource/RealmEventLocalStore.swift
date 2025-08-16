//
//  RealmEventLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/7/25.
//

import Foundation

final class RealmEventLocalStore: EventLocalStore {
    private let db: DatabaseActor
    private let auth: AuthProviding
    
    init(db: DatabaseActor, auth: AuthProviding) {
        self.db = db
        self.auth = auth
    }
    
    func fetchAll() async throws -> [EventLocal] {
        try await db.fetchAllEventsSorted()
    }
    
    func fetch(id: UUID) async throws -> EventLocal? {
        try await db.fetchEvent(id: id)
    }
    
    func fetch(startAt: Date) async throws -> Event? {
        let filter = EventFilter(userId: auth.userId, startDateRange: startAt...startAt)
        let events = try await db.fetchEvents(filteredBy: filter)
        if let event = events.first {
            return Event(local: event)
        }
        return nil
    }

    func upsert(_ event: EventRemote) async throws {
        try await db.upsertEvent(from: event, userId: auth.userId)
    }

    func upsert(_ event: EventLocal) async throws {
        try await db.upsertEvent(from: event, userId: auth.userId)
    }
    
    func upsert(event: EventLocal, rule: RecurrenceRule) async throws {
        try await db.upsertEvent(local: event, rule: rule, userId: auth.userId)
    }

    func delete(id: UUID) async throws {
        try await db.softDeleteEvent(id: id, userId: auth.userId)
    }

    func deleteAll(for userId: UUID) async throws {
        try await db.deleteAllEvents(for: userId)
    }

    func deleteAll() async throws {
        try await db.deleteAllEvents()
    }
}

extension RealmEventLocalStore {
    func fetchOccurrences(for userId: UUID?) async throws -> [EventOccurrenceResponse] {
        guard let uid = userId ?? auth.userId else {
            throw StoreError.invalidData("User must be either authenticated or id passed as parameter!")
        }
        return try await db.fetchOccurrences(userId: uid)
    }
    
    func splitRecurringEvent(
        originalEventId: UUID,
        splitDate: Date,
        newEvent: EventLocal
    ) async throws -> UUID {
        guard let userId = auth.userId else {
            throw StoreError.invalidData("User must be either authenticated or id passed as parameter!")
        }
        
        return try await db.splitRecurringEventFrom(
            originalEventId: originalEventId,
            splitDate: splitDate,
            newEvent: newEvent,
            userId: userId
        )
    }
}
