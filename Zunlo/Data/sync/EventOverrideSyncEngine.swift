//
//  EventOverrideSyncEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import Supabase
import RealmSwift

final class EventOverrideSyncEngine {
    private let db: DatabaseActor
    private let supabase: SupabaseClient
    private let pageSize = 500
    private let lastPullKey = "event_overrides.lastPulledAt"

    init(db: DatabaseActor, supabase: SupabaseClient) {
        self.db = db
        self.supabase = supabase
    }

    func syncNow() async -> (Int, Int) {
        do {
            let pushed = try await pushDirty()
            let pulled = try await pullSinceCursor()
            return (pushed, pulled)
        } catch {
            print("EventOverride sync error:", error)
            return (0, 0)
        }
    }

    private func pushDirty() async throws -> Int {
        let (batch, ids) = try await db.readDirtyEventOverrides()
        guard !batch.isEmpty else { return 0 }
        _ = try await supabase.from("event_overrides").upsert(batch, onConflict: "id").execute()
        try await db.markEventOverridesClean(ids)
        return batch.count
    }

    private func pullSinceCursor() async throws -> Int {
        var since = UserDefaults.standard.string(forKey: lastPullKey) ?? "1970-01-01T00:00:00Z"
        var lastServerUpdatedAt: Date?

        var rowsAffected = 0
        
        while true {
            let data = try await supabase
                .from("event_overrides")
                .select()
                .gt("updated_at", value: since)
                .order("updated_at", ascending: true)
                .limit(pageSize)
                .execute()
                .data

            let rows: [EventOverrideRemote] = try data.decodeSupabase()
            
            rowsAffected += rows.count
            
            guard !rows.isEmpty else { break }
            lastServerUpdatedAt = rows.last?.updated_at
            try await db.applyRemoteEventOverrides(rows)
            if let last = lastServerUpdatedAt { since = last.nextMillisecondCursor() }
        }

        if let last = lastServerUpdatedAt {
            UserDefaults.standard.set(last.nextMillisecondCursor(), forKey: lastPullKey)
        }
        
        return rowsAffected
    }
}
