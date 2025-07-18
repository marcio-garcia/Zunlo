//
//  SupabaseEventRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/29/25.
//

import Foundation
import SupabaseSDK

enum StoreError: Error, LocalizedError {
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidData(let field): return "Invalid input data: \(field)"
        }
    }
}

final class SupabaseEventRemoteStore: EventRemoteStore {
    private let tableName = "events"
    private var supabase: SupabaseSDK
    private var authManager: AuthSession

    private var authToken: String? { authManager.accessToken }
    private var database: SupabaseDatabase { supabase.database(authToken: authToken) }

    init(supabase: SupabaseSDK, authManager: AuthSession) {
        self.supabase = supabase
        self.authManager = authManager
    }

    func fetchAll() async throws -> [EventRemote] {
        try await database.fetch(from: tableName, as: EventRemote.self, query: ["select": "*"])
    }
    
    func fecthOccurrences() async throws -> [EventOccurrenceRemote] {
        try await database.fetchOccurrences(as: EventOccurrenceRemote.self)
    }

    func save(_ event: EventRemote) async throws -> [EventRemote] {
        // Only nil the ID if creating a new record and let Supabase/DB handle it
        var ev = event
        ev.id = nil
        ev.user_id = nil
        ev.created_at = nil
        return try await database.insert(ev, into: tableName)
    }

    func update(_ event: EventRemote) async throws -> [EventRemote] {
        guard let id = event.id?.uuidString else {
            assertionFailure("SupabaseEventRemoteStore - update(_ rule:) - id == nil")
            return []
        }
        var ev = event
        ev.id = nil
        ev.user_id = nil
        ev.created_at = nil
        return try await database.update(ev, in: tableName, filter: ["id": "eq.\(id)"])
    }

    func delete(id: UUID) async throws -> [EventRemote] {
        return try await database.delete(from: tableName, filter: ["id": "eq.\(id)"])
    }

    func deleteAll(for userId: UUID) async throws -> [EventRemote] {
        try await database.delete(from: tableName, filter: ["user_id": "eq.\(userId.uuidString)"])
    }
}
