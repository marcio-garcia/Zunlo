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
    
    func fetchOccurrences(for userId: UUID) async throws -> [EventOccurrence] {
        return events
    }
    
    func fetchOccurrences(id: UUID) async throws -> Zunlo.EventOccurrence? {
        return events.first { $0.id == id }
    }
}
