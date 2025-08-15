//
//  RecurrenceRuleSyncEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import Supabase
import RealmSwift

final class RecurrenceRuleSyncEngine {
    private let db: DatabaseActor
    private let supabase: SupabaseClient
    private let pageSize = 500
    private let lastPullKey = "recurrence_rules.lastPulledAt"

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
            print("RecurrenceRule sync error:", error)
            return (0, 0)
        }
    }

    private func pushDirty() async throws -> Int {
        let (batch, ids) = try await db.readDirtyRecurrenceRules()
        guard !batch.isEmpty else { return 0 }
        _ = try await supabase.from("recurrence_rules").upsert(batch, onConflict: "id").execute()
        try await db.markRecurrenceRulesClean(ids)
        return batch.count
    }

    private func pullSinceCursor() async throws -> Int {
        var since = UserDefaults.standard.string(forKey: lastPullKey) ?? "1970-01-01T00:00:00Z"
        var lastServerUpdatedAt: Date?

        var rowsAffected = 0
        
        while true {
            let data = try await supabase
                .from("recurrence_rules")
                .select()
                .gt("updated_at", value: since)
                .order("updated_at", ascending: true)
                .limit(pageSize)
                .execute()
                .data

            let rows: [RecurrenceRuleRemote] = try data.decodeSupabase()
            
            rowsAffected += rows.count
            
            guard !rows.isEmpty else { break }
            lastServerUpdatedAt = rows.last?.updated_at
            try await db.applyRemoteRecurrenceRules(rows)
            if let last = lastServerUpdatedAt { since = last.nextMillisecondCursor() }
        }

        if let last = lastServerUpdatedAt {
            UserDefaults.standard.set(last.nextMillisecondCursor(), forKey: lastPullKey)
        }
        
        return rowsAffected
    }
}
