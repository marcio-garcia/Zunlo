//
//  EventOverrideLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation

@MainActor
protocol EventOverrideLocalStore {
    func fetchAll() async throws -> [EventOverride]
    func fetch(for eventId: UUID) async throws -> [EventOverride]
    func save(_ overrideRemote: EventOverrideRemote) async throws
    func update(_ overrideRemote: EventOverrideRemote) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
}
