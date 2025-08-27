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
    private let api: SyncAPI
    private let pageSize = 100
    private let tableName = "tasks"
    
    init(db: DatabaseActor, api: SyncAPI) {
        self.db = db
        self.api = api
    }
    
    func makeRunner() -> SyncRunner<UserTaskRemote, TaskInsertPayload, TaskUpdatePayload> {
        return makeTaskRunner(db: db, api: api)
    }
    
    // Mappers (using your insert/update payloads)
    func taskInsert(_ r: UserTaskRemote) -> TaskInsertPayload { TaskInsertPayload(remote: r) }
    func taskUpdate(_ r: UserTaskRemote) -> TaskUpdatePayload { TaskUpdatePayload.full(from: r) }

    func makeTaskRunner(db: DatabaseActor, api: SyncAPI) -> SyncRunner<UserTaskRemote, TaskInsertPayload, TaskUpdatePayload> {
        let spec = SyncSpec<UserTaskRemote, TaskInsertPayload, TaskUpdatePayload>(
            entityKey: self.tableName,
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
            applyPage: { rows in try await db.applyPage(for: self.tableName, rows: rows) { realm, rows in
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
            readCursor: { try await db.readCursor(for: self.tableName) },

            // Mappers
            isInsert: { $0.isInsertCandidate },
            makeInsertPayload: taskInsert,
            makeUpdatePayload: taskUpdate
        )
        return SyncRunner(spec: spec)
    }
}
