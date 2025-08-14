//
//  UserTaskSyncEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import Supabase

final class UserTaskSyncEngine {
    private let db: DatabaseActor
    private let supabase: SupabaseClient
    private let pageSize = 500
    private let lastTsKey = "tasks.cursor.ts"
    private let lastIdKey = "tasks.cursor.id"

    init(db: DatabaseActor, supabase: SupabaseClient) {
        self.db = db
        self.supabase = supabase
    }

    func syncNow() async {
        do { try await pushDirty(); try await pullSinceCursor() }
        catch { print("UserTask sync error:", error) }
    }

    private func pushDirty() async throws {
        let (batch, ids) = try await db.readDirtyUserTasks()
        guard !batch.isEmpty else { return }
        _ = try await supabase.from("tasks").upsert(batch, onConflict: "id").execute()
        try await db.markUserTasksClean(ids)
    }

    private func pullSinceCursor() async throws {
        var sinceTs = UserDefaults.standard.string(forKey: lastTsKey) ?? "1970-01-01T00:00:00.000000Z"
        var sinceId  = UserDefaults.standard.string(forKey: lastIdKey).flatMap(UUID.init)

        var lastTsSeen: Date?
        var lastIdSeen: UUID?

        while true {
            let idStr = sinceId?.uuidString ?? "00000000-0000-0000-0000-000000000000"
            let data = try await supabase
                .from("tasks")
                .select()
                .or("updated_at.gt.\(sinceTs),and(updated_at.eq.\(sinceTs),id.gt.\(idStr))")
                .order("updated_at", ascending: true)
                .order("id", ascending: true)
                .limit(pageSize)
                .execute()
                .data
            
            let rows: [UserTaskRemote] = try data.decodeSupabase()
            
            guard !rows.isEmpty else { break }
            
            try await db.applyRemoteUserTasks(rows)
            
            if let last = rows.last {
                lastTsSeen = last.updatedAt
                lastIdSeen = last.id
                sinceTs = last.updatedAt.nextMillisecondCursor()
                sinceId = last.id
            }
        }

        if let t = lastTsSeen, let id = lastIdSeen {
            UserDefaults.standard.set(t.nextMillisecondCursor(), forKey: lastTsKey)
            UserDefaults.standard.set(id.uuidString, forKey: lastIdKey)
        }
    }
}
