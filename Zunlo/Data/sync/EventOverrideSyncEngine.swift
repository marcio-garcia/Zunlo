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
    private let api: SyncAPI
    private let pageSize = 500
    private let lastTsKey = "event_overrides.lastTimestampAt"
    private let lastIdKey = "event_overrides.lastIdAt"

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
            print("EventOverride sync error:", error)
            return (0, 0)
        }
    }

//    private func pushDirty() async throws -> Int {
//        let (batch, ids) = try await db.readDirtyEventOverrides()
//        guard !batch.isEmpty else { return 0 }
//        _ = try await supabase.from("event_overrides").upsert(batch, onConflict: "id").execute()
//        try await db.markEventOverridesClean(ids)
//        return batch.count
//    }

    private func pullSinceCursor() async throws -> Int {
        var sinceTs = UserDefaults.standard.string(forKey: lastTsKey) ?? CursorDefaults.zero
        var sinceId = UserDefaults.standard.string(forKey: lastIdKey).flatMap(UUID.init)
        var lastServerUpdatedAt: Date?

        var rowsAffected = 0
        
        while true {
            let rows = try await api.fetchEventOverridesToSync(
                sinceTimestamp: sinceTs,
                sinceID: sinceId,
                pageSize: pageSize
            )
            
            rowsAffected += rows.count
            
            guard !rows.isEmpty else { break }
            try await db.applyRemoteEventOverrides(rows)
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
    
    private func pushDirty() async throws -> Int {
        let (batch, _) = try await db.readDirtyEventOverrides()
        guard !batch.isEmpty else { return 0 }

        var pushed: [UUID] = []
        var conflicts: [(EventOverrideRemote, EventOverrideRemote?)] = []

        let inserts = batch.filter { $0.version == nil }
        let updates = batch.filter { $0.version != nil }

        // INSERT
        if !inserts.isEmpty {
            do {
                let inserted = try await api.insertEventOverridesReturning(inserts)
                try await db.applyRemoteEventOverrides(inserted)
                pushed.append(contentsOf: inserted.map(\.id))
            } catch {
                for dto in inserts {
                    do {
                        let rows = try await api.insertEventOverridesReturning([dto])
                        if let row = rows.first {
                            try await db.applyRemoteEventOverrides([row])
                            pushed.append(row.id)
                        }
                    } catch {
                        let server = try? await api.fetchEventOverride(id: dto.id)
                        conflicts.append((dto, server))
                    }
                }
            }
        }

        // Guarded UPDATE
        for dto in updates {
            do {
                if let updated = try await api.updateEventOverrideIfVersionMatches(dto) {
                    try await db.applyRemoteEventOverrides([updated])
                    pushed.append(updated.id)
                } else {
                    let server = try? await api.fetchEventOverride(id: dto.id)
                    conflicts.append((dto, server))
                }
            } catch {
                let server = try? await api.fetchEventOverride(id: dto.id)
                conflicts.append((dto, server))
            }
        }

        try await db.markEventOverridesClean(pushed)
        
        // conflicts: [(local: EventOverrideRemote, server: EventOverrideRemote?)]
        if !conflicts.isEmpty {
            try await db.recordConflicts(
                .event_overrides,
                items: conflicts,
                idOf: { $0.id },
                localVersion: { $0.version },
                remoteVersion: { $0?.version }
            )
        }
        
        return pushed.count
    }

}
