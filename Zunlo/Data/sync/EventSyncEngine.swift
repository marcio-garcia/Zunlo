//
//  EventSyncEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import RealmSwift
import Supabase

private enum CursorDefaults {
    static let zero = "1970-01-01T00:00:00.000000Z"
}

final class EventSyncEngine {
    private let db: DatabaseActor
    private let supabase: SupabaseClient
    private let pageSize = 500
    private let lastTsKey = "events.lastTimestampAt"
    private let lastIdKey = "events.lastIdAt"

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
            print("Event sync error:", error)
            return (0, 0)
        }
    }

    private func pushDirty() async throws -> Int {
        let (batch, ids) = try await db.readDirtyEvents()
        guard !batch.isEmpty else { return 0 }
        _ = try await supabase.from("events").upsert(batch, onConflict: "id").execute()
        try await db.markEventsClean(ids)
        return batch.count
    }

    private func pullSinceCursor() async throws -> Int {
        var sinceTs = UserDefaults.standard.string(forKey: lastTsKey) ?? CursorDefaults.zero
        var sinceId = UserDefaults.standard.string(forKey: lastIdKey).flatMap(UUID.init)

        var lastServerUpdatedAt: Date?

        var rowsAffected = 0
        
        while true {
            let data = try await supabase
                .from("events")
                .select()
                .or("updated_at.gt.\(sinceTs),and(updated_at.eq.\(sinceTs),id.gt.\(sinceId?.uuidString ?? "00000000-0000-0000-0000-000000000000"))")
                .order("updated_at", ascending: true)
                .order("id", ascending: true)
                .limit(pageSize)
                .execute()
                .data
            
            let rows: [EventRemote] = try data.decodeSupabase()

            rowsAffected += rows.count
            
            guard !rows.isEmpty else { break }
            try await db.applyRemoteEvents(rows)
            if let last = rows.last {
                lastServerUpdatedAt = last.updated_at
                sinceTs = last.updated_at.nextMillisecondCursor()
                sinceId = last.id
            }
        }

        if let last = lastServerUpdatedAt {
            UserDefaults.standard.set(last.nextMillisecondCursor(), forKey: lastTsKey)
            UserDefaults.standard.set(sinceId?.uuidString, forKey: lastIdKey)
        }
        
        return rowsAffected
    }
}

extension Data {
    func decodeSupabase<T: Decodable>() throws -> T {
        return try JSONDecoder.supabaseMicroFirst().decode(T.self, from: self)
    }
}
