//
//  EventLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/29/25.
//

import Foundation

protocol EventLocalStore {
    func upsert(_ event: EventRemote) async throws
    func upsert(_ event: Event) async throws
    func upsert(event: Event, rule: RecurrenceRule) async throws
    func delete(id: UUID) async throws
    func deleteAll(for userId: UUID) async throws
    func deleteAll() async throws
    
    func fetchAll() async throws -> [Event]
    func fetchOccurrences(for userId: UUID?) async throws -> [EventOccurrenceResponse]
    
    func splitRecurringEvent(
        originalEventId: UUID,
        splitDate: Date,
        newEvent: Event
    ) async throws -> UUID
}
