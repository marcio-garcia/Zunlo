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
    
    private var authToken: String? {
        return authManager.accessToken
    }
    
    private var database: SupabaseDatabase {
        return supabase.database(authToken: authToken)
    }
    
    init(supabase: SupabaseSDK, authManager: AuthSession) {
        self.supabase = supabase
        self.authManager = authManager
    }
    
    func fetch() async throws -> [EventRemote] {
        return try await supabase.database(
            authToken: authToken
        ).fetch(from: tableName, as: EventRemote.self, query: ["select": "*"])
    }
    
    func save(_ event: EventRemote) async throws -> [EventRemote] {
        var ev = event
        ev.id = nil
        ev.userId = nil
        ev.createdAt = nil
        return try await database.insert(ev, into: tableName)
    }
    
    func update(_ event: EventRemote) async throws -> [EventRemote] {
        guard let id = event.id?.uuidString else {
            throw StoreError.invalidData("\(tableName).id")
        }
        var ev = event
        ev.id = nil
        ev.userId = nil
        ev.createdAt = nil
        return try await database.update(ev, in: tableName, filter: ["id": "eq.\(id)"])
    }
    
    func delete(_ event: EventRemote) async throws -> [EventRemote] {
        guard let id = event.id?.uuidString else {
            throw StoreError.invalidData("\(tableName).id")
        }
        return try await database.delete(from: tableName, filter: ["id" : "eq.\(id)"])
    }
    
    func deleteAll() async throws -> [EventRemote] {
        guard let userId = authManager.auth?.user.id else {
            throw StoreError.invalidData("\(tableName).user_id")
        }
        return try await database.delete(from: tableName, filter: ["userId" : "eq.\(userId)"])
    }
}
