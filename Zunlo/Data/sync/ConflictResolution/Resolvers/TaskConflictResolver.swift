//
//  TaskConflictResolver.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

import Foundation

// MARK: - Tasks

final class TaskConflictResolver: AnyConflictResolver {
    let table = "tasks"
    private let api: SyncAPI

    init(api: SyncAPI) {
        self.api = api
    }

    func attemptAutoResolve(conflict: ConflictData, db: ConflictDB) async {
        do {
            let remote: UserTaskRemote = try decodeJSON(conflict.remoteJSON ?? "{}", as: UserTaskRemote.self)
            let local:  UserTaskRemote = try decodeJSON(conflict.localJSON, as: UserTaskRemote.self)
            let base:   UserTaskRemote = try {
                if let b = conflict.baseJSON { return try decodeJSON(b, as: UserTaskRemote.self) }
                return remote
            }()

            // --- json3WayMerge (exclude reminder_triggers) ---
            let structural: Set<String>  = ["parent_event_id"]
            let serverOwned: Set<String> = ["id", "user_id", "created_at", "updated_at", "version"]
            let newerWins: Set<String>   = ["title", "notes", "due_date", "priority"] // intentionally NOT "reminder_triggers"

            var mergedObj = json3WayMerge(
                base:  toObject(conflict.baseJSON ?? conflict.remoteJSON ?? "{}"),
                local: toObject(conflict.localJSON),
                remote: toObject(conflict.remoteJSON ?? "{}"),
                structuralKeys: structural,
                serverOwnedKeys: serverOwned,
                newerWinsKeys: newerWins,
                localUpdatedAtISO: local.updatedAtRaw,
                remoteUpdatedAtISO: remote.updatedAtRaw
            )

            // Rebuild typed merged from server, then overlay mergedObj
            
            if mergedObj["id"] == nil { mergedObj["id"] = remote.id.uuidString }
            if mergedObj["user_id"] == nil { mergedObj["user_id"] = remote.userId.uuidString }
            if mergedObj["created_at"] == nil { mergedObj["created_at"] = RFC3339MicrosUTC.string(remote.createdAt) }
            if mergedObj["updated_at"] == nil { mergedObj["updated_at"] = RFC3339MicrosUTC.string(remote.updatedAt) }
            if mergedObj["version"] == nil { mergedObj["version"] = remote.version }
            
            var merged = remote
            let mergedJSON = toJSON(mergedObj)
            let partial: UserTaskRemote = try decodeJSON(mergedJSON, as: UserTaskRemote.self)
            merged = overlayTask(base: remote, overlay: partial)

            // --- Task-specific rules ---

            // 1) Completion wins
            if local.isCompleted != base.isCompleted || remote.isCompleted != base.isCompleted {
                merged.isCompleted = local.isCompleted || remote.isCompleted
            }

            // 2) Notes double-edit fallback (append)
            if local.notes != base.notes && remote.notes != base.notes {
                let ln = local.notes ?? ""
                let rn = remote.notes ?? ""
                merged.notes = ln.isEmpty ? rn : (rn.isEmpty ? ln : ln + "\n----\n" + rn)
            }

            // 3) Tags 3-way set merge
//            do {
//                let b = Set(base.tags), l = Set(local.tags), s = Set(remote.tags)
//                let adds = (l.subtracting(b)).union(s.subtracting(b))
//                let removals = (b.subtracting(l)).union(b.subtracting(s))
//                merged.tags = Array((b.union(adds)).subtracting(removals)).sorted()
//            }

            // 4) reminderTriggers — SIMPLE: newer-wins WHOLE ARRAY (with canonicalization)
            let baseTrig   = canonicalTriggers(base.reminderTriggers)
            let localTrig  = canonicalTriggers(local.reminderTriggers)
            let remoteTrig = canonicalTriggers(remote.reminderTriggers)

            let localChanged  = localTrig != baseTrig
            let remoteChanged = remoteTrig != baseTrig

            if localChanged && remoteChanged {
                merged.reminderTriggers = (local.updatedAtRaw ?? "") > (remote.updatedAtRaw ?? "")
                    ? localTrig : remoteTrig
            } else if localChanged {
                merged.reminderTriggers = localTrig
            } else if remoteChanged {
                merged.reminderTriggers = remoteTrig
            } else {
                merged.reminderTriggers = remoteTrig // no change; keep server
            }

            // 5) DeletedAt: prefer any tombstone
            if let localDel = local.deletedAt { merged.deletedAt = localDel }
            if let serverDel = remote.deletedAt { merged.deletedAt = serverDel }

            // Guarded PATCH
            let expected = remote.version ?? -1
            let patch = TaskUpdatePayload.full(from: merged)
            if let updated = try await api.updateUserTaskIfVersionMatchesPatch(
                id: merged.id, expectedVersion: expected, patch: patch
            ) {
                try await db.applyRemoteUserTasks([updated])
                try await db.resolveConflict(conflictId: conflict.id, strategy: .autoMerged)
            } else {
                try await db.setConflictNeedsUser(conflictId: conflict.id, reason: "Version changed during task merge")
            }
        } catch {
            try? await db.failConflict(conflictId: conflict.id, error: error)
        }
    }

    private func overlayTask(base: UserTaskRemote, overlay: UserTaskRemote) -> UserTaskRemote {
        var out = base
        if overlay.title != base.title { out.title = overlay.title }
        if overlay.notes != base.notes { out.notes = overlay.notes }
        if overlay.isCompleted != base.isCompleted { out.isCompleted = overlay.isCompleted }
        if overlay.dueDate != base.dueDate { out.dueDate = overlay.dueDate }
        if overlay.priority != base.priority { out.priority = overlay.priority }
        if overlay.parentEventId != base.parentEventId { out.parentEventId = overlay.parentEventId }
        if overlay.tags != base.tags { out.tags = overlay.tags }
        if overlay.reminderTriggers != base.reminderTriggers { out.reminderTriggers = overlay.reminderTriggers }
        if overlay.deletedAt != base.deletedAt { out.deletedAt = overlay.deletedAt }
        return out
    }

    // Stable ordering so harmless reordering doesn’t cause conflicts/noise.
    private func canonicalTriggers(_ arr: [ReminderTrigger]?) -> [ReminderTrigger]? {
        guard var a = arr, !a.isEmpty else { return arr }
        a.sort {
            if $0.timeBeforeDue != $1.timeBeforeDue { return $0.timeBeforeDue < $1.timeBeforeDue }
            return ($0.message ?? "") < ($1.message ?? "")
        }
        return a
    }
}
