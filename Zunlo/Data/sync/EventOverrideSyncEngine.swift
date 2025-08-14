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

    func syncNow() async {
        do {
            try await pushDirty()
            try await pullSinceCursor()
        } catch {
            print("EventOverride sync error:", error)
        }
    }

    private func pushDirty() async throws {
        let (batch, ids) = try await db.readDirtyEventOverrides()
        guard !batch.isEmpty else { return }
        _ = try await supabase.from("event_overrides").upsert(batch, onConflict: "id").execute()
        try await db.markEventOverridesClean(ids)
    }

    private func pullSinceCursor() async throws {
        var since = UserDefaults.standard.string(forKey: lastPullKey) ?? "1970-01-01T00:00:00Z"
        var lastServerUpdatedAt: Date?

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
            
            guard !rows.isEmpty else { break }
            lastServerUpdatedAt = rows.last?.updated_at
            try await db.applyRemoteEventOverrides(rows)
            if let last = lastServerUpdatedAt { since = last.nextMillisecondCursor() }
        }

        if let last = lastServerUpdatedAt {
            UserDefaults.standard.set(last.nextMillisecondCursor(), forKey: lastPullKey)
        }
    }
}
