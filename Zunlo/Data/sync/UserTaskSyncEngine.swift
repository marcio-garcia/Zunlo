//
//  UserTaskSyncEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import Supabase

enum SyncError: Error {
    case message(String)
}

final class UserTaskSyncEngine {
    private let db: DatabaseActor
    private let api: SyncAPI
    private let pageSize = 100
    
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
            print("UserTask sync error:", error)
            // return partials we have so far
            let message = """
            Sync error: \(error.localizedDescription)
            \(SyncReport.from(push: push, pull: pull))
            """
            throw SyncError.message(message)
        }
        return SyncReport.from(push: push, pull: pull)
    }
//    
//    private func pullSinceCursor() async throws -> PullStats {
//        var (sinceTs, sinceTsRaw, sinceId) = try await db.readCursor(for: "tasks")
//        var stats = PullStats.zero
//                
//        while true {
//            let rows = try await api.fetchUserTasksToSync(
//                sinceTimestamp: sinceTsRaw ?? RFC3339MicrosUTC.string(sinceTs),
//                sinceID: sinceId, // nil on first page => uses only updated_at > ts
//                pageSize: pageSize
//            )
//            guard !rows.isEmpty else { break }
//
//            // atomically upsert + advance DB cursor
//            try await db.applyTaskSync(rows: rows)
//            
//            // advance local cursor too, so the next page request moves forward
//            if let last = rows.last {
//                sinceTs = last.updatedAt
//                sinceTsRaw = last.updatedAtRaw
//                sinceId = last.id
//            }
//            
//            stats.pulled += rows.count
//            stats.pages += 1
//        }
//
//        return stats
//    }

    private func pullSinceCursor() async throws -> PullStats {
        var (sinceTs, sinceTsRaw, sinceId) = try await db.readCursor(for: "tasks")
        var stats = PullStats.zero

        while true {
            let since = sinceTsRaw ?? RFC3339MicrosUTC.string(sinceTs)
            let rows = try await api.fetchUserTasksToSync(
                sinceTimestamp: since,
                sinceID: sinceId,
                pageSize: pageSize
            )
            guard !rows.isEmpty else { break }

            // Atomically upsert the page and advance the DB cursor.
            try await db.applyPage(for: "tasks", rows: rows) { realm, rows in
                for r in rows {
                    if let tomb = r.deletedAt {
                        if let obj = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: r.id) {
                            obj.deletedAt = tomb
                            obj.needsSync = false
                            obj.version = r.version
                        }
                        continue
                    }
                    let obj = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: r.id) ?? {
                        let o = UserTaskLocal(); o.id = r.id; return o
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
        let (batch, _) = try await db.readDirtyUserTasks()
        guard !batch.isEmpty else { return .zero }

        var pushedIDs: [UUID] = []
        var conflictsToRecord: [(UserTaskRemote, UserTaskRemote?)] = []
        var stats = PushStats.zero
        
        let inserts = batch.filter { $0.version == nil }
        let updates = batch.filter { $0.version != nil }

        // INSERT
        if !inserts.isEmpty {
            do {
                let payloads = inserts.map(TaskInsertPayload.init(remote:))
                let inserted = try await api.insertUserTasksPayloadReturning(payloads)
                try await db.applyRemoteUserTasks(inserted)
                pushedIDs.append(contentsOf: inserted.map(\.id))
                stats.inserted += inserted.count
            } catch {
                print("sync error: \(error.localizedDescription)")
                // Bulk failed. Retry per-item and classify.
                for dto in inserts {
                    do {
                        let rows = try await api.insertUserTasksPayloadReturning([TaskInsertPayload(remote: dto)])
                        if let row = rows.first {
                            try await db.applyRemoteUserTasks([row])
                            pushedIDs.append(row.id)
                            stats.inserted += 1
                        }
                    } catch {
                        switch classify(error) {
                        case .conflict:
                            // Likely duplicate id unique_violation.
                            let server = try? await api.fetchUserTask(id: dto.id)
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
                if let updated = try await api.updateUserTaskIfVersionMatchesPatch(
                    id: dto.id,
                    expectedVersion: expectedVersion,
                    patch: TaskUpdatePayload.full(from: dto)
                ) {
                    try await db.applyRemoteUserTasks([updated])
                    pushedIDs.append(updated.id)
                    stats.updated += 1
                } else {
                    let server = try? await api.fetchUserTask(id: dto.id)
                    conflictsToRecord.append((dto, server))
                    stats.conflicts += 1
                }
            } catch {
                switch classify(error) {
                case .conflict:
                    let server = try? await api.fetchUserTask(id: dto.id)
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

        try await db.markUserTasksClean(pushedIDs)
        
        // conflicts: [(local: UserTaskRemote, server: UserTaskRemote?)]
        if !conflictsToRecord.isEmpty {
            try await db.recordConflicts(
                .tasks,
                items: conflictsToRecord,
                idOf: { $0.id },
                localVersion: { $0.version },
                remoteVersion: { $0?.version }
            )
        }
        
        return stats
    }
    
    // Call await maybeBackoff(classify(error)) where you want pacing.
    private func maybeBackoff(_ kind: FailureKind) async {
        switch kind {
        case .rateLimited(let retryAfter):
            try? await Task.sleep(nanoseconds: UInt64((retryAfter ?? 2.0) * 1_000_000_000))
        case .transient:
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        default:
            break
        }
    }
    
    // Mappers (using your insert/update payloads)
    func taskInsert(_ r: UserTaskRemote) -> TaskInsertPayload { TaskInsertPayload(remote: r) }
    func taskUpdate(_ r: UserTaskRemote) -> TaskUpdatePayload { TaskUpdatePayload.full(from: r) }

    func makeTaskRunner(db: DatabaseActor, api: SupabaseSyncAPI) -> SyncRunner<UserTaskRemote, TaskInsertPayload, TaskUpdatePayload> {
        let spec = SyncSpec<UserTaskRemote, TaskInsertPayload, TaskUpdatePayload>(
            entityKey: "tasks",
            pageSize: 100,

            // API
            fetchSince: { ts, id, size in try await api.fetchUserTasksToSync(sinceTimestamp: ts, sinceID: id, pageSize: size) },
            fetchOne: { id in try await api.fetchUserTask(id: id) },
            insertReturning: { payloads in try await api.insertUserTasksPayloadReturning(payloads) }, // see note below
            updateIfVersionMatches: { row, patch in
                let expected = row.version ?? -1
                return try await api.updateUserTaskIfVersionMatchesPatch(id: row.id, expectedVersion: expected, patch: patch)
            },

            // DB
            readDirty: { try await db.readDirtyUserTasks().0 }, // your existing return
            applyPage: { rows in try await db.applyPage(for: "tasks", rows: rows) { realm, rows in
                for r in rows {
                    if let tomb = r.deletedAt {
                        if let obj = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: r.id) {
                            obj.deletedAt = tomb; obj.needsSync = false; obj.version = r.version
                        }
                        continue
                    }
                    let obj = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: r.id) ?? { let o = UserTaskLocal(); o.id = r.id; return o }()
                    obj.getUpdateFields(remote: r); obj.needsSync = false
                    realm.add(obj, update: .modified)
                }
            }},
            markClean: { ids in try await db.markUserTasksClean(ids) },
            recordConflicts: { items in
                try await db.recordConflicts(.tasks, items: items, idOf: { $0.id }, localVersion: { $0.version }, remoteVersion: { $0?.version })
            },
            readCursor: { try await db.readCursor(for: "tasks") },

            // Mappers
            isInsert: { $0.isInsertCandidate },
            makeInsertPayload: taskInsert,
            makeUpdatePayload: taskUpdate
        )
        return SyncRunner(spec: spec)
    }

}
