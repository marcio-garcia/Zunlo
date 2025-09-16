//
//  FakeEventStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

import Foundation
@testable import Zunlo

final class FakeEventFetcher: EventStore {
    var events: [EventOccurrence]
    
    init(_ events: [EventOccurrence]) {
        self.events = events
    }
    
    func fetchOccurrences() async throws -> [EventOccurrence] {
        return events
    }
    
    func fetchOccurrences(id: UUID) async throws -> Zunlo.EventOccurrence? {
        return events.first { $0.id == id }
    }
    
    func makeEvent(title: String, start: Date, end: Date) -> Zunlo.Event? {
        return Event(id: UUID(), userId: UUID(), title: title, startDate: start, endDate: end, isRecurring: false, createdAt: Date(), updatedAt: Date(), color: .yellow, needsSync: true)
    }
    
    func fetchEvent(by id: UUID) async throws -> Zunlo.Event? {
        return makeEvent(title: "", start: Date(), end: Date())
    }
    
    func fetchOccurrences(in range: Range<Date>) async throws -> [Zunlo.EventOccurrence] {
        return events
    }
    
    func upsert(_ event: Zunlo.Event) async throws {
        
    }

    func add(_ input: Zunlo.AddEventInput) async throws {
        events.append(EventOccurrence(startDate: input.startDate, endDate: input.endDate))
    }
    
    func editAll(event: Zunlo.EventOccurrence, with input: Zunlo.EditEventInput, oldRule: Zunlo.RecurrenceRule?) async throws {
        
    }
    
    func editSingle(parent: Zunlo.EventOccurrence, occurrence: Zunlo.EventOccurrence, with input: Zunlo.EditEventInput) async throws {
        
    }
    
    func editOverride(_ override: Zunlo.EventOverride, with input: Zunlo.EditEventInput) async throws {
        
    }
    
    func editFuture(parent: Zunlo.EventOccurrence, startingFrom occurrence: Zunlo.EventOccurrence, with input: Zunlo.EditEventInput) async throws {
        
    }
    
    func delete(id: UUID) async throws {
    }
}
