//
//  RealmEventOverrideLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/7/25.
//

import Foundation
import RealmSwift

final class RealmEventOverrideLocalStore: EventOverrideLocalStore {
    private let db: DatabaseActor
    init(db: DatabaseActor) { self.db = db }

    func fetchAll() async throws -> [EventOverride] {
        try await db.fetchAllEventOverrides()
    }

    func fetch(for eventId: UUID) async throws -> [EventOverride] {
        try await db.fetchOverrides(for: eventId)
    }

    func save(_ overrideRemote: EventOverrideRemote) async throws {
        try await db.upsertOverride(from: overrideRemote)
    }

    func save(_ override: EventOverride) async throws {
        try await db.upsertOverride(from: override)
    }

    func upsert(_ remote: EventOverrideRemote) async throws {
        try await db.upsertOverride(from: remote)
    }

    func upsert(_ domain: EventOverride) async throws {
        try await db.upsertOverride(from: domain)
    }

    func delete(id: UUID) async throws {
        try await db.softDeleteOverride(id: id)
    }

    func deleteAll() async throws {
        try await db.deleteAllOverrides()
    }
}
