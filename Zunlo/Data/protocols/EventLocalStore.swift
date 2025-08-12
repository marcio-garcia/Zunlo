//
//  EventLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/29/25.
//

import Foundation

protocol EventLocalStore {
    func fetchAll() async throws -> [Event]
    func fetchOccurrences(for userId: UUID?) async throws -> [EventOccurrenceResponse]
    func save(_ remoteEvent: EventRemote) async throws
    func update(_ event: EventRemote) async throws
    func delete(id: UUID) async throws
    func deleteAll(for userId: UUID) async throws
    func deleteAll() async throws
}
