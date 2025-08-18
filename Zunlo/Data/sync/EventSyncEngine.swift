//
//  EventSyncEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import RealmSwift
import Supabase

enum CursorDefaults {
    static let zero = "1970-01-01T00:00:00.000000Z"
}

final class EventSyncEngine {
    private let db: DatabaseActor
    private let api: SyncAPI
    private let pageSize = 500
    private let tableName = "events"
    private let lastTsKey = "events.lastTimestampAt"
    private let lastIdKey = "events.lastIdAt"
    
    init(db: DatabaseActor, api: SyncAPI) {
        self.db = db
        self.api = api
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

//    private func pushDirty() async throws -> Int {
//        let (batch, ids) = try await db.readDirtyEvents()
//        guard !batch.isEmpty else { return 0 }
//        _ = try await supabase.from("events").upsert(batch, onConflict: "id").execute()
//        try await db.markEventsClean(ids)
//        return batch.count
//    }

    private func pullSinceCursor() async throws -> Int {
        var sinceTs = UserDefaults.standard.string(forKey: lastTsKey) ?? CursorDefaults.zero
        var sinceId = UserDefaults.standard.string(forKey: lastIdKey).flatMap(UUID.init)

        var lastServerUpdatedAt: Date?

        var rowsAffected = 0
        
        while true {
            let rows = try await api.fetchEventsToSync(
                sinceTimestamp: sinceTs,
                sinceID: sinceId,
                pageSize: pageSize
            )

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
    
    /// v2 push: optimistic concurrency with `version`
    /// - Returns: number of rows successfully pushed (inserted or updated)
    private func pushDirty() async throws -> Int {
        // 1) Read local dirty rows (each as EventRemote with .version set or nil)
        let (batch, _) = try await db.readDirtyEvents()
        guard !batch.isEmpty else { return 0 }

        var pushedIds: [UUID] = []
        var conflicts: [(local: EventRemote, server: EventRemote?)] = []

        // 2) Split into inserts vs guarded updates
        let inserts  = batch.filter { $0.version == nil }
        let updates  = batch.filter { $0.version != nil }

        // 3) INSERT new rows in bulk, returning representation to capture server version (v=1)
        if !inserts.isEmpty {
            do {
                let inserted = try await api.insertEventsReturning(inserts)

                if !inserted.isEmpty {
                    try await db.applyRemoteEvents(inserted)            // writes server fields & version; sets needsSync = false
                    pushedIds.append(contentsOf: inserted.compactMap(\.id))
                }
            } catch {
                // Fallback: try row-by-row insert; on failure, fetch server row and flag conflict
                for dto in inserts {
                    do {
                        let rows = try await api.insertEventsReturning([dto])
                        if let row = rows.first {
                            try await db.applyRemoteEvents([row])
                            pushedIds.append(row.id)
                        }
                    } catch {
                        // Could be duplicate id (already on server) or RLS; fetch server to surface conflict info
                        let server = try? await api.fetchEvent(id: dto.id)
                        conflicts.append((local: dto, server: server))
                    }
                }
            }
        }

        // 4) Guarded UPDATE per row: version match required
        for dto in updates {
            guard /*let id = dto.id, */let expected = dto.version else { continue }
            do {
                let rows = try await api.updateEventIfVersionMatches(dto)
                if let updated = rows {
                    try await db.applyRemoteEvents([updated])           // captures bumped server version; clears needsSync
                    pushedIds.append(updated.id)
                } else {
                    // 0 rows updated -> conflict
                    let server = try? await api.fetchEvent(id: dto.id)
                    conflicts.append((local: dto, server: server))
                }
            } catch {
                // Network/permission/etc. Try to fetch server row for better diagnostics
                let server = try? await api.fetchEvent(id: dto.id)
                conflicts.append((local: dto, server: server))
            }
        }

        // 5) Mark only successes clean
        try await db.markEventsClean(pushedIds)

        // conflicts: [(local: EventRemote, server: EventRemote?)]
        if !conflicts.isEmpty {
            try await db.recordConflicts(
                .events,
                items: conflicts,
                idOf: { $0.id },
                localVersion: { $0.version },
                remoteVersion: { $0?.version }
            )
        }

        return pushedIds.count
    }
}
