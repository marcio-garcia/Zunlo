//
//  SupabaseRecurrenceRuleRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

//import Foundation
//import SupabaseSDK
//
//final class SupabaseRecurrenceRuleRemoteStore: RecurrenceRuleRemoteStore {
//    private let tableName = "recurrence_rules"
//    private var supabase: SupabaseSDK
//    private var auth: AuthProviding
//
//    private var authToken: String? { auth.accessToken }
//    private var database: SupabaseDatabase { supabase.database(authToken: authToken) }
//
//    init(supabase: SupabaseSDK, auth: AuthProviding) {
//        self.supabase = supabase
//        self.auth = auth
//    }
//
//    func fetchAll() async throws -> [RecurrenceRuleRemote] {
//        try await database.fetch(from: tableName, as: RecurrenceRuleRemote.self, query: ["select": "*"])
//    }
//    
//    func fetch(for eventId: UUID) async throws -> [RecurrenceRuleRemote] {
//        try await database.fetch(from: tableName, as: RecurrenceRuleRemote.self, query: ["event_id": "eq.\(eventId.uuidString)"])
//    }
//
//    func save(_ rule: RecurrenceRuleRemote) async throws -> [RecurrenceRuleRemote] {
//        return try await database.insert(rule, into: tableName)
//    }
//
//    func update(_ rule: RecurrenceRuleRemote) async throws -> [RecurrenceRuleRemote] {
//        return try await database.update(rule, in: tableName, filter: ["id": "eq.\(rule.id.uuidString)"])
//    }
//
//    func delete(_ rule: RecurrenceRuleRemote) async throws -> [RecurrenceRuleRemote] {
//        return try await database.delete(from: tableName, filter: ["id": "eq.\(rule.id.uuidString)"])
//    }
//}
