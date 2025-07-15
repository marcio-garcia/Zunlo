//
//  SupabasePushTokensRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/15/25.
//

import Foundation
import SupabaseSDK

final class SupabasePushTokensRemoteStore: PushTokensRemoteStore {
    private let tableName = "push_tokens"
    private var supabase: SupabaseSDK
    private var authManager: AuthSession

    private var authToken: String? { authManager.accessToken }
    private var database: SupabaseDatabase { supabase.database(authToken: authToken) }

    init(supabase: SupabaseSDK, authManager: AuthSession) {
        self.supabase = supabase
        self.authManager = authManager
    }

    func fetchAll() async throws -> [PushTokenRemote] {
        return []
    }

    func save(_ remote: PushTokenRemote) async throws -> [PushTokenRemote] {
        var re = remote
        re.id = nil
        let headers = ["Prefer": "resolution=merge-duplicates"]
        return try await database.insert(re, into: tableName, additionalHeaders: headers)
    }

    func update(_ remote: PushTokenRemote) async throws -> [PushTokenRemote] {
        guard let id = remote.id else {
            assertionFailure("SupabaseEventRemoteStore - update(_ rule:) - id == nil")
            return []
        }
        return try await database.update(remote, in: tableName, filter: ["id": "eq.\(id)"])
    }

    func delete(_ remote: PushTokenRemote) async throws -> [PushTokenRemote] {
        guard let id = remote.id else {
            assertionFailure("SupabaseEventRemoteStore - delete(_ rule:) - id == nil")
            return []
        }
        return try await database.delete(from: tableName, filter: ["id": "eq.\(id)"])
    }

    func deleteAll(for userId: UUID) async throws -> [PushTokenRemote] {
        try await database.delete(from: tableName, filter: ["user_id": "eq.\(userId.uuidString)"])
    }
}
