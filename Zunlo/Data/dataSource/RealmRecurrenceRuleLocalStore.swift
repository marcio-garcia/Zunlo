//
//  RealmRecurrenceRuleLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/7/25.
//

import Foundation
import RealmSwift

final class RealmRecurrenceRuleLocalStore: RecurrenceRuleLocalStore {
    private let db: DatabaseActor
    init(db: DatabaseActor) { self.db = db }

    func fetchAll() async throws -> [RecurrenceRuleLocal] {
        try await db.fetchAllRecurrenceRules()
    }

    func fetch(for eventId: UUID) async throws -> [RecurrenceRuleLocal] {
        try await db.fetchRecurrenceRules(for: eventId)
    }

    func save(_ remote: RecurrenceRuleRemote) async throws {
        try await db.upsertRecurrenceRule(from: remote)
    }

    func save(_ domain: RecurrenceRule) async throws {
        try await db.upsertRecurrenceRule(from: domain)
    }

    func upsert(_ remote: RecurrenceRuleRemote) async throws {
        try await db.upsertRecurrenceRule(from: remote)
    }

    func upsert(_ domain: RecurrenceRule) async throws {
        try await db.upsertRecurrenceRule(from: domain)
    }

    func delete(eventId: UUID) async throws {
        let rules = try await fetch(for: eventId)
        for rule in rules {
            try await delete(id: rule.id)
        }
    }
    
    func delete(id: UUID) async throws {
        try await db.softDeleteRecurrenceRule(id: id)
    }

    func deleteAll() async throws {
        try await db.deleteAllRecurrenceRules()
    }
    
    func apply(rows: [RecurrenceRuleRemote]) async throws {
        try await db.applyRemoteRecurrenceRules(rows)
    }
}
