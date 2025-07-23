//
//  SupabaseEventOverrideRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation
import SupabaseSDK

final class SupabaseEventOverrideRemoteStore: EventOverrideRemoteStore {
    private let tableName = "event_overrides"
    private var supabase: SupabaseSDK
    private var authManager: AuthManager

    private var authToken: String? { authManager.authToken?.accessToken }
    private var database: SupabaseDatabase { supabase.database(authToken: authToken) }

    init(supabase: SupabaseSDK, authManager: AuthManager) {
        self.supabase = supabase
        self.authManager = authManager
    }
    
    func fetchAll() async throws -> [EventOverrideRemote] {
        try await database.fetch(from: tableName, as: EventOverrideRemote.self, query: ["select": "*"])
    }

    func fetch(for eventId: UUID) async throws -> [EventOverrideRemote] {
        try await database.fetch(from: tableName, as: EventOverrideRemote.self, query: ["event_id": "eq.\(eventId.uuidString)"])
    }

    func save(_ override: EventOverrideRemote) async throws -> [EventOverrideRemote] {
        var ov = override
        ov.id = nil
        ov.created_at = nil
        ov.updated_at = nil
        return try await database.insert(ov, into: tableName)
    }

    func update(_ override: EventOverrideRemote) async throws -> [EventOverrideRemote] {
        guard let id = override.id?.uuidString else {
            assertionFailure("SupabaseEventOverrideRemoteStore - update(_ override:) - id == nil")
            return []
        }
        return try await database.update(override, in: tableName, filter: ["id": "eq.\(id)"])
    }

    func delete(_ override: EventOverrideRemote) async throws -> [EventOverrideRemote] {
        guard let id = override.id?.uuidString else {
            assertionFailure("SupabaseEventOverrideRemoteStore - delete(_ override:) - id == nil")
            return []
        }
        return try await database.delete(from: tableName, filter: ["id": "eq.\(id)"])
    }
}

