//
//  EventRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/29/25.
//

import Foundation

protocol EventRemoteStore {
    func fetchAll() async throws -> [EventRemote]
    func fetchOccurrences() async throws -> [EventOccurrenceRemote]
    func save(_ event: EventRemote) async throws -> [EventRemote]
    func update(_ event: EventRemote) async throws -> [EventRemote]
    func delete(id: UUID) async throws -> [EventRemote]
    func deleteAll(for userId: UUID) async throws -> [EventRemote]
    func splitRecurringEvent(_ occurrence: SplitRecurringEventRemote) async throws -> SplitRecurringEventResponse
}
