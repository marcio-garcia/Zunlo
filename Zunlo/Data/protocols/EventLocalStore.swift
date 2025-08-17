//
//  EventLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/29/25.
//

import Foundation

protocol EventLocalStore {
    func upsert(_ event: EventRemote) async throws
    func upsert(_ event: EventLocal) async throws
    func upsert(event: EventLocal, rule: RecurrenceRule) async throws
    func delete(id: UUID) async throws
    func deleteAll(for userId: UUID) async throws
    func deleteAll() async throws
    
    func fetch(id: UUID) async throws -> EventLocal?
    func fetch(startAt: Date) async throws -> EventLocal?
    func fetch(filteredBy filter: EventFilter) async throws -> [EventLocal]
    func fetchAll() async throws -> [EventLocal]
    func fetchOccurrences(for userId: UUID?) async throws -> [EventOccurrenceResponse]
    
    func splitRecurringEvent(
        originalEventId: UUID,
        splitDate: Date,
        newEvent: EventLocal
    ) async throws -> UUID
}
