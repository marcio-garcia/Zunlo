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

    func fetchAll() async throws -> [Event] {
        try await db.fetchAllEventsSorted()
    }

    func upsert(_ event: EventRemote) async throws {
        try await db.upsertEvent(from: event, userId: auth.userId)
    }

    func upsert(_ event: Event) async throws {
        try await db.upsertEvent(from: event, userId: auth.userId)
    }
    
    func upsert(event: Event, rule: RecurrenceRule) async throws {
        try await db.upsertEvent(event: event, rule: rule, userId: auth.userId)
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
        newEvent: Event
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
