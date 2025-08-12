//
//  EventFetcher.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/10/25.
//

import Foundation

protocol EventFetcherService {
    func fetchOccurrences() async throws -> [EventOccurrence]
    func fetchLocalOcc(for userId: UUID) async throws -> [EventOccurrence]
}

final class EventFetcher: EventFetcherService {
    private let repo: EventRepository
    private let clock: () -> Date
    
    init(repo: EventRepository, clock: @escaping () -> Date = Date.init) {
        self.repo = repo
        self.clock = clock
    }
    
    func fetchOccurrences() async throws -> [EventOccurrence] {
        let occ = try await repo.fetchOccurrences()
        try await repo.synchronize()
        return occ
    }
    
    func fetchLocalOcc(for userId: UUID) async throws -> [EventOccurrence] {
        return try await repo.fetchLocalOcc(for: userId)
    }
}
