//
//  EventConflictResolver.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

final class EventConflictResolver: AnyConflictResolver {
    let table = "events"
    private let api: SyncAPI

    init(api: SyncAPI) {
        self.api = api
    }

    func attemptAutoResolve(conflict: ConflictData, db: ConflictDB) async {
        do {
            // Decode typed snapshots; if base missing, use remote as base
            let remote: EventRemote = try decodeJSON(conflict.remoteJSON ?? "{}", as: EventRemote.self)
            let local:  EventRemote = try decodeJSON(conflict.localJSON, as: EventRemote.self)
            let base:   EventRemote = try {
                if let b = conflict.baseJSON { return try decodeJSON(b, as: EventRemote.self) }
                return remote
            }()

            // --- json3WayMerge (we'll handle reminder_triggers explicitly afterward) ---
            let structural: Set<String>  = ["series_id", "original_event_id", "recurrence_rule_id"]
            let serverOwned: Set<String> = ["created_at", "updated_at", "version"]
            let newerWins: Set<String>   = ["title", "location", "notes", "start_at", "end_at", "is_all_day"]
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

            // Rebuild typed merged from server snapshot, then overlay mergedObj
            
            if mergedObj["id"] == nil { mergedObj["id"] = remote.id.uuidString }
            if mergedObj["created_at"] == nil { mergedObj["created_at"] = RFC3339MicrosUTC.string(remote.createdAt) }
            if mergedObj["updated_at"] == nil { mergedObj["updated_at"] = RFC3339MicrosUTC.string(remote.updatedAt) }
            if mergedObj["version"] == nil { mergedObj["version"] = remote.version }
            
            var merged = remote
            let mergedJSON = toJSON(mergedObj)
            let partial: EventRemote = try decodeJSON(mergedJSON, as: EventRemote.self)
            merged = applyOverlay(base: remote, overlay: partial)

            // --- Event-specific rules ---

            // 1) Notes double-edit fallback (append sections) – optional but mirrors Tasks
            if local.notes != base.notes && remote.notes != base.notes {
                let ln = local.notes ?? ""
                let rn = remote.notes ?? ""
                merged.notes = ln.isEmpty ? rn : (rn.isEmpty ? ln : ln + "\n----\n" + rn)
            }

            // 2) reminderTriggers — SIMPLE: newer-wins WHOLE ARRAY (with canonicalization)
            let baseTrig   = canonicalTriggers(base.reminder_triggers)
            let localTrig  = canonicalTriggers(local.reminder_triggers)
            let remoteTrig = canonicalTriggers(remote.reminder_triggers)

            let localChanged  = localTrig != baseTrig
            let remoteChanged = remoteTrig != baseTrig

            if localChanged && remoteChanged {
                merged.reminder_triggers = (local.updatedAtRaw ?? "") > (remote.updatedAtRaw ?? "")
                    ? localTrig : remoteTrig
            } else if localChanged {
                merged.reminder_triggers = localTrig
            } else if remoteChanged {
                merged.reminder_triggers = remoteTrig
            } else {
                merged.reminder_triggers = remoteTrig // unchanged; keep server
            }

            // 3) DeletedAt: prefer any tombstone (server or local)
            if let localDel = local.deletedAt { merged.deletedAt = localDel }
            if let serverDel = remote.deletedAt { merged.deletedAt = serverDel }

            // Guarded PATCH (expected = server version)
            let expected = remote.version ?? -1
            let patch = EventUpdatePayload.full(from: merged)
            if let updated = try await api.updateEventIfVersionMatchesPatch(
                id: merged.id,
                expectedVersion: expected,
                patch: patch
            ) {
                try await db.applyRemoteEvents([updated])
                try await db.resolveConflict(conflictId: conflict.id, strategy: .autoMerged)
            } else {
                try await db.setConflictNeedsUser(conflictId: conflict.id, reason: "Version changed during event merge")
            }

        } catch {
            try? await db.failConflict(conflictId: conflict.id, error: error)
        }
    }

    // Copies overlay fields decided by json3WayMerge into the server snapshot.
    // Adjust the property list to match your actual EventRemote model.
    // Overlay helper: take non-nil/changed fields from overlay into base
    private func applyOverlay(base: EventRemote, overlay: EventRemote) -> EventRemote {
        var out = base
        // Adjust for your real EventRemote fields:
        if overlay.title != base.title { out.title = overlay.title }
        if overlay.notes != base.notes { out.notes = overlay.notes }
        if overlay.start_datetime != base.start_datetime { out.start_datetime = overlay.start_datetime }
        if overlay.end_datetime != base.end_datetime { out.end_datetime = overlay.end_datetime }
        if overlay.is_recurring != base.is_recurring { out.is_recurring = overlay.is_recurring }
        if overlay.location != base.location { out.location = overlay.location }
        if overlay.color != base.color { out.color = overlay.color }
        if overlay.reminder_triggers != base.reminder_triggers { out.reminder_triggers = overlay.reminder_triggers }
        if overlay.deletedAt != base.deletedAt { out.deletedAt = overlay.deletedAt }
//        if overlay.isAllDay != base.isAllDay { out.isAllDay = overlay.isAllDay }
        // Keep server-owned fields: createdAt/updatedAt/version remain from base
        return out
    }

    // Stable ordering so harmless reordering doesn’t cause churn.
    private func canonicalTriggers(_ arr: [ReminderTrigger]?) -> [ReminderTrigger]? {
        guard var a = arr, !a.isEmpty else { return arr }
        a.sort {
            if $0.timeBeforeDue != $1.timeBeforeDue { return $0.timeBeforeDue < $1.timeBeforeDue }
            return ($0.message ?? "") < ($1.message ?? "")
        }
        return a
    }
}
