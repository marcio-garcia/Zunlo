//
//  SupabaseRecurrenceRuleRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation
import SupabaseSDK

final class SupabaseRecurrenceRuleRemoteStore: RecurrenceRuleRemoteStore {
    private let tableName = "recurrence_rules"
    private var supabase: SupabaseSDK
    private var authManager: AuthSession

    private var authToken: String? { authManager.authToken?.accessToken }
    private var database: SupabaseDatabase { supabase.database(authToken: authToken) }

    init(supabase: SupabaseSDK, authManager: AuthSession) {
        self.supabase = supabase
        self.authManager = authManager
    }

    func fetchAll() async throws -> [RecurrenceRuleRemote] {
        try await database.fetch(from: tableName, as: RecurrenceRuleRemote.self, query: ["select": "*"])
    }
    
    func fetch(for eventId: UUID) async throws -> [RecurrenceRuleRemote] {
        try await database.fetch(from: tableName, as: RecurrenceRuleRemote.self, query: ["event_id": "eq.\(eventId.uuidString)"])
    }

    func save(_ rule: RecurrenceRuleRemote) async throws -> [RecurrenceRuleRemote] {
        var ruleToSave = rule
        ruleToSave.id = nil
        return try await database.insert(ruleToSave, into: tableName)
    }

    func update(_ rule: RecurrenceRuleRemote) async throws -> [RecurrenceRuleRemote] {
        guard let id = rule.id?.uuidString else {
            assertionFailure("SupabaseRecurrenceRuleRemoteStore - update(_ rule:) - id == nil")
            return []
        }
        return try await database.update(rule, in: tableName, filter: ["id": "eq.\(id)"])
    }

    func delete(_ rule: RecurrenceRuleRemote) async throws -> [RecurrenceRuleRemote] {
        guard let id = rule.id?.uuidString else {
            assertionFailure("SupabaseRecurrenceRuleRemoteStore - delete(_ rule:) - id == nil")
            return []
        }
        return try await database.delete(from: tableName, filter: ["id": "eq.\(id)"])
    }
}
