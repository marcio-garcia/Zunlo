//
//  FakeEventStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

import Foundation
@testable import Zunlo

final class FakeEventFetcher: EventFetcherService {
    
    var events: [EventOccurrence]
    
    init(_ events: [EventOccurrence]) {
        self.events = events
    }
    
    func fetchOccurrences() async throws -> [Zunlo.EventOccurrence] {
        return events
    }
    
    func fetchLocalOcc(for userId: UUID) async throws -> [Zunlo.EventOccurrence] {
        return events
    }
}
