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
    private var auth: AuthProviding

    private var authToken: String? { auth.accessToken }
    private var database: SupabaseDatabase { supabase.database(authToken: authToken) }

    init(supabase: SupabaseSDK, auth: AuthProviding) {
        self.supabase = supabase
        self.auth = auth
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
    
    func fecthOccurrences() async throws -> [EventOccurrenceResponse] {
        try await database.fetchOccurrences(as: EventOccurrenceResponse.self)
    }

    func save(_ task: UserTaskRemote) async throws -> [UserTaskRemote] {
        // Only nil the ID if creating a new record and let Supabase/DB handle it
        var tk = task
        tk.userId = nil
        tk.createdAt = nil
        return try await database.insert(tk, into: tableName)
    }

    func update(_ task: UserTaskRemote) async throws -> [UserTaskRemote] {
        var tk = task
        tk.userId = nil
        tk.createdAt = nil
        return try await database.update(tk, in: tableName, filter: ["id": "eq.\(task.id.uuidString)"])
    }

    func delete(_ id: UUID) async throws -> [UserTaskRemote] {
        return try await database.delete(from: tableName, filter: ["id": "eq.\(id)"])
    }

    func deleteAll(for userId: UUID) async throws -> [UserTaskRemote] {
        try await database.delete(from: tableName, filter: ["user_id": "eq.\(userId.uuidString)"])
    }
}
