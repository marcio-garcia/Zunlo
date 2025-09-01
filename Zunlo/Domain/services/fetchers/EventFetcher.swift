//
//  EventFetcher.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/10/25.
//

import Foundation

protocol EventFetcherService {
    func fetchOccurrences(for userId: UUID) async throws -> [EventOccurrence]
    func fetchOccurrences(id: UUID) async throws -> EventOccurrence?
}

final class EventFetcher: EventFetcherService {
    private let repo: EventRepository
    private let clock: () -> Date
    
    init(repo: EventRepository, clock: @escaping () -> Date = Date.init) {
        self.repo = repo
        self.clock = clock
    }
    
    func fetchOccurrences(for userId: UUID) async throws -> [EventOccurrence] {
        return try await repo.fetchOccurrences(for: userId)
    }
    
    func fetchOccurrences(id: UUID) async throws -> EventOccurrence? {
        return try await repo.fetchOccurrences(id: id)
    }
}
