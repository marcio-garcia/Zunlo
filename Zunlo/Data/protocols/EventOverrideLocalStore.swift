//
//  EventOverrideLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation

protocol EventOverrideLocalStore {
    func fetchAll() async throws -> [EventOverride]
    func fetch(for eventId: UUID) async throws -> [EventOverride]
    func save(_ overrideRemote: EventOverrideRemote) async throws
    func save(_ override: EventOverride) async throws
    func upsert(_ remote: EventOverrideRemote) async throws
    func upsert(_ domain: EventOverride) async throws
    func delete(eventId: UUID) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
    func apply(rows: [EventOverrideRemote]) async throws
}
