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
    private let pageSize = 500
    private let lastTsKey = "tasks.cursor.ts"
    private let lastIdKey = "tasks.cursor.id"

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
            print("UserTask sync error:", error)
            return (0, 0)
        }
    }

//    private func pushDirty() async throws -> Int {
//        let (batch, ids) = try await db.readDirtyUserTasks()
//        guard !batch.isEmpty else { return 0 }
//        _ = try await supabase.from("tasks").upsert(batch, onConflict: "id").execute()
//        try await db.markUserTasksClean(ids)
//        return batch.count
//    }

    private func pullSinceCursor() async throws -> Int {
        var sinceTs = UserDefaults.standard.string(forKey: lastTsKey) ?? "1970-01-01T00:00:00.000000Z"
        var sinceId  = UserDefaults.standard.string(forKey: lastIdKey).flatMap(UUID.init)

        var lastTsSeen: Date?
        var lastIdSeen: UUID?

        var rowsAffected = 0
        
        while true {
            let rows = try await api.fetchUserTasksToSync(
                sinceTimestamp: sinceTs,
                sinceID: sinceId,
                pageSize: pageSize
            )
            
            rowsAffected += rows.count
            
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
        
        return rowsAffected
    }
    
    private func pushDirty() async throws -> Int {
        let (batch, _) = try await db.readDirtyUserTasks()
        guard !batch.isEmpty else { return 0 }

        var pushed: [UUID] = []
        var conflicts: [(UserTaskRemote, UserTaskRemote?)] = []

        let inserts = batch.filter { $0.version == nil }
        let updates = batch.filter { $0.version != nil }

        // INSERT
        if !inserts.isEmpty {
            do {
                let inserted = try await api.insertUserTasksReturning(inserts)
                try await db.applyRemoteUserTasks(inserted)
                pushed.append(contentsOf: inserted.map(\.id))
            } catch {
                for dto in inserts {
                    do {
                        let rows = try await api.insertUserTasksReturning([dto])
                        if let row = rows.first {
                            try await db.applyRemoteUserTasks([row])
                            pushed.append(row.id)
                        }
                    } catch {
                        let server = try? await api.fetchUserTask(id: dto.id)
                        conflicts.append((dto, server))
                    }
                }
            }
        }

        // Guarded UPDATE
        for dto in updates {
            do {
                if let updated = try await api.updateUserTaskIfVersionMatches(dto) {
                    try await db.applyRemoteUserTasks([updated])
                    pushed.append(updated.id)
                } else {
                    let server = try? await api.fetchUserTask(id: dto.id)
                    conflicts.append((dto, server))
                }
            } catch {
                let server = try? await api.fetchUserTask(id: dto.id)
                conflicts.append((dto, server))
            }
        }

        try await db.markUserTasksClean(pushed)
        
        // conflicts: [(local: UserTaskRemote, server: UserTaskRemote?)]
        if !conflicts.isEmpty {
            try await db.recordConflicts(
                .tasks,
                items: conflicts,
                idOf: { $0.id },
                localVersion: { $0.version },
                remoteVersion: { $0?.version }
            )
        }
        
        return pushed.count
    }

}
