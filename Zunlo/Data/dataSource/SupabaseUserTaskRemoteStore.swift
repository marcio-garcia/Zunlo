//
//  SupabaseUserTaskRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation
import SupabaseSDK

final class SupabaseUserTaskRemoteStore: UserTaskRemoteStore {
    
    private let tableName = "tasks"
    private var supabase: SupabaseSDK
    private var authManager: AuthSession

    private var authToken: String? { authManager.authToken?.accessToken }
    private var database: SupabaseDatabase { supabase.database(authToken: authToken) }

    init(supabase: SupabaseSDK, authManager: AuthSession) {
        self.supabase = supabase
        self.authManager = authManager
    }

    func propertyName<T, V>(_ keyPath: KeyPath<T, V>) -> String? {
        return NSExpression(forKeyPath: keyPath).keyPath
    }
    
    func fetchAll() async throws -> [UserTaskRemote] {
        try await database.fetch(
            from: tableName,
            as: UserTaskRemote.self,
            query: [
                "select": "*",
                "order": "\(UserTaskRemote.CodingKeys.priority.rawValue).desc,\(UserTaskRemote.CodingKeys.dueDate.rawValue).asc"
            ]
        )
    }
    
    func fecthOccurrences() async throws -> [EventOccurrenceRemote] {
        try await database.fetchOccurrences(as: EventOccurrenceRemote.self)
    }

    func save(_ task: UserTaskRemote) async throws -> [UserTaskRemote] {
        // Only nil the ID if creating a new record and let Supabase/DB handle it
        var tk = task
        tk.id = nil
        tk.userId = nil
        tk.createdAt = nil
        return try await database.insert(tk, into: tableName)
    }

    func update(_ task: UserTaskRemote) async throws -> [UserTaskRemote] {
        guard let id = task.id?.uuidString else {
            assertionFailure("SupabaseEventRemoteStore - update(_ rule:) - id == nil")
            return []
        }
        var tk = task
        tk.id = nil
        tk.userId = nil
        tk.createdAt = nil
        return try await database.update(tk, in: tableName, filter: ["id": "eq.\(id)"])
    }

    func delete(_ task: UserTaskRemote) async throws -> [UserTaskRemote] {
        guard let id = task.id?.uuidString else {
            assertionFailure("SupabaseEventRemoteStore - delete(_ rule:) - id == nil")
            return []
        }
        return try await database.delete(from: tableName, filter: ["id": "eq.\(id)"])
    }

    func deleteAll(for userId: UUID) async throws -> [UserTaskRemote] {
        try await database.delete(from: tableName, filter: ["user_id": "eq.\(userId.uuidString)"])
    }
}
