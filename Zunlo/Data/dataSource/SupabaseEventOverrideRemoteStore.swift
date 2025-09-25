//
//  SupabaseEventOverrideRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

//import Foundation
//import SupabaseSDK
//
//final class SupabaseEventOverrideRemoteStore: EventOverrideRemoteStore {
//    private let tableName = "event_overrides"
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
//    func fetchAll() async throws -> [EventOverrideRemote] {
//        try await database.fetch(from: tableName, as: EventOverrideRemote.self, query: ["select": "*"])
//    }
//
//    func fetch(for eventId: UUID) async throws -> [EventOverrideRemote] {
//        try await database.fetch(from: tableName, as: EventOverrideRemote.self, query: ["event_id": "eq.\(eventId.uuidString)"])
//    }
//
//    func save(_ override: EventOverrideRemote) async throws -> [EventOverrideRemote] {
//        return try await database.insert(override, into: tableName)
//    }
//
//    func update(_ override: EventOverrideRemote) async throws -> [EventOverrideRemote] {
//        return try await database.update(override, in: tableName, filter: ["id": "eq.\(override.id.uuidString)"])
//    }
//
//    func delete(_ override: EventOverrideRemote) async throws -> [EventOverrideRemote] {
//        return try await database.delete(from: tableName, filter: ["id": "eq.\(override.id.uuidString)"])
//    }
//}

