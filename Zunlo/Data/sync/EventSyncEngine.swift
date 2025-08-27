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
    private let pageSize = 100
    private let tableName = "events"
    
    init(db: DatabaseActor, api: SyncAPI) {
        self.db = db
        self.api = api
    }
    
    func syncNow() async throws -> SyncReport {
        var push = PushStats.zero
        var pull = PullStats.zero
        do {
            push = try await pushDirty()
            pull = try await pullSinceCursor()
        } catch {
            print("Event sync error:", error)
            // return partials we have so far
            let message = """
            Sync error: \(error.localizedDescription)
            \(SyncReport.from(push: push, pull: pull))
            """
            throw SyncError.message(message)
        }
        return SyncReport.from(push: push, pull: pull)
    }
    
    private func pullSinceCursor() async throws -> PullStats {
        var (sinceTs, sinceTsRaw, sinceId) = try await db.readCursor(for: tableName)
        var stats = PullStats.zero

        while true {
            let since = sinceTsRaw ?? RFC3339MicrosUTC.string(sinceTs)
            let rows = try await api.fetchEventsToSync(
                sinceTimestamp: since,
                sinceID: sinceId,
                pageSize: pageSize
            )
            guard !rows.isEmpty else { break }

            // Atomically upsert the page and advance the DB cursor.
            try await db.applyPage(for: tableName, rows: rows) { realm, rows in
                for r in rows {
                    if let tomb = r.deletedAt {
                        if let obj = realm.object(ofType: EventLocal.self, forPrimaryKey: r.id) {
                            obj.deletedAt = tomb
                            obj.needsSync = false
                            obj.version = r.version
                        }
                        continue
                    }
                    let obj = realm.object(ofType: EventLocal.self, forPrimaryKey: r.id) ?? {
                        let o = EventLocal(); o.id = r.id; return o
                    }()
                    obj.getUpdateFields(remote: r)
                    obj.needsSync = false
                    realm.add(obj, update: .modified)
                }
            }

            // Advance local cursor for the next request.
            if let last = rows.last {
                sinceTs = last.updatedAt
                sinceTsRaw = last.updatedAtRaw
                sinceId = last.id
            }

            stats.pulled += rows.count
            stats.pages += 1
        }

        return stats
    }
    
    private func pushDirty() async throws -> PushStats {
        let (batch, _) = try await db.readDirtyEvents()
        guard !batch.isEmpty else { return .zero }

        var pushedIDs: [UUID] = []
        var conflictsToRecord: [(EventRemote, EventRemote?)] = []
        var stats = PushStats.zero
        
        let inserts = batch.filter { $0.version == nil }
        let updates = batch.filter { $0.version != nil }

        // INSERT
        if !inserts.isEmpty {
            do {
                let payloads = inserts.map(EventInsertPayload.init(remote:))
                let inserted = try await api.insertEventsPayloadReturning(payloads)
                try await db.applyRemoteEvents(inserted)
                pushedIDs.append(contentsOf: inserted.map(\.id))
                stats.inserted += inserted.count
            } catch {
                print("sync error: \(error.localizedDescription)")
                // Bulk failed. Retry per-item and classify.
                for dto in inserts {
                    do {
                        let rows = try await api.insertEventsPayloadReturning([EventInsertPayload(remote: dto)])
                        if let row = rows.first {
                            try await db.applyRemoteEvents([row])
                            pushedIDs.append(row.id)
                            stats.inserted += 1
                        }
                    } catch {
                        switch classify(error) {
                        case .conflict:
                            // Likely duplicate id unique_violation.
                            let server = try? await api.fetchEvent(id: dto.id)
                            conflictsToRecord.append((dto, server))       // record real conflict
                            stats.conflicts += 1
                        case .missing:
                            // weird for insert; log, but don't mark conflict
                            print("sync error: \(error.localizedDescription)")
                            stats.missing += 1
                        case .rateLimited(let retryAfter):
                            // leave dirty; retry on next sync
                            print("sync error: \(error.localizedDescription)")
                            stats.rateLimited += 1
                            await maybeBackoff(.rateLimited(retryAfter: retryAfter))
                        case .transient:
                            stats.transientFailures += 1
                            await maybeBackoff(.transient)
                        case .permanent:
                            // validation/RLS. surface to UI later if needed.
                            print("sync error: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }

        // Guarded UPDATE
        for dto in updates {
            do {
                let expectedVersion = dto.version ?? -1
                if let updated = try await api.updateEventIfVersionMatchesPatch(
                    id: dto.id,
                    expectedVersion: expectedVersion,
                    patch: EventUpdatePayload.full(from: dto)
                ) {
                    try await db.applyRemoteEvents([updated])
                    pushedIDs.append(updated.id)
                    stats.updated += 1
                } else {
                    let server = try? await api.fetchEvent(id: dto.id)
                    conflictsToRecord.append((dto, server))
                    stats.conflicts += 1
                }
            } catch {
                switch classify(error) {
                case .conflict:
                    let server = try? await api.fetchEvent(id: dto.id)
                    conflictsToRecord.append((dto, server))
                    stats.conflicts += 1
                case .missing:
                    // server row was deleted: decide policy (mark local deleted, or turn into insert)
                    // Here: treat as "missing", not a conflict; do not record.
                    print("sync error: \(error.localizedDescription)")
                    stats.missing += 1
                case .rateLimited(let retryAfter):
                    // retry later
                    print("sync error: \(error.localizedDescription)")
                    stats.rateLimited += 1
                    await maybeBackoff(.rateLimited(retryAfter: retryAfter))
                case .transient:
                    stats.transientFailures += 1
                    await maybeBackoff(.transient)
                case .permanent:
                    // log; do not record conflict
                    print("sync error: \(error.localizedDescription)")
                }
            }
        }

        try await db.markEventsClean(pushedIDs)
        
        if !conflictsToRecord.isEmpty {
            try await db.recordConflicts(
                .events,
                items: conflictsToRecord,
                idOf: { $0.id },
                localVersion: { $0.version },
                remoteVersion: { $0?.version }
            )
        }
        
        return stats
    }
}
