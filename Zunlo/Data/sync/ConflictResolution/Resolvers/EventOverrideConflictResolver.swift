//
//  EventOverrideConflictResolver.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

final class EventOverrideConflictResolver: AnyConflictResolver {
    let table = "event_overrides"
    private let api: SyncAPI

    init(api: SyncAPI) {
        self.api = api
    }

    func attemptAutoResolve(conflict: ConflictData, db: ConflictDB) async {
        do {
            let remote: EventOverrideRemote = try decodeJSON(conflict.remoteJSON ?? "{}", as: EventOverrideRemote.self)
            let local: EventOverrideRemote  = try decodeJSON(conflict.localJSON, as: EventOverrideRemote.self)
            let base: EventOverrideRemote   = try {
                if let b = conflict.baseJSON { return try decodeJSON(b, as: EventOverrideRemote.self) }
                return remote
            }()

            let structural: Set<String> = ["event_id"]                 // server always wins on parent link
            let serverOwned: Set<String> = ["created_at", "updated_at", "version"]
            let newerWins: Set<String> = ["title", "notes", "start_at", "end_at", "is_all_day", "location"]

            let mergedObj = json3WayMerge(
                base: toObject(conflict.baseJSON ?? conflict.remoteJSON ?? "{}"),
                local: toObject(conflict.localJSON),
                remote: toObject(conflict.remoteJSON ?? "{}"),
                structuralKeys: structural,
                serverOwnedKeys: serverOwned,
                newerWinsKeys: newerWins,
                localUpdatedAtISO: local.updatedAtRaw,
                remoteUpdatedAtISO: remote.updatedAtRaw
            )

            let mergedJSON = toJSON(mergedObj)
            var merged = remote
            let partial: EventOverrideRemote = try decodeJSON(mergedJSON, as: EventOverrideRemote.self)
            merged = overlayOverride(base: remote, overlay: partial, baseSnap: base, localSnap: local, remoteSnap: remote)

            let expected = remote.version ?? -1
            if let updated = try await api.updateOverrideIfVersionMatchesPatch(
                id: merged.id,
                expectedVersion: expected,
                patch: EventOverrideUpdatePayload.full(from: merged)
            ) {
                try await db.applyRemoteEventOverrides([updated])
                try await db.resolveConflict(conflictId: conflict.id, strategy: .autoMerged)
            } else {
                try await db.setConflictNeedsUser(conflictId: conflict.id, reason: "Version changed during override merge")
            }
        } catch {
            try? await db.failConflict(conflictId: conflict.id, error: error)
        }
    }

    private func overlayOverride(
        base: EventOverrideRemote,
        overlay: EventOverrideRemote,
        baseSnap: EventOverrideRemote,
        localSnap: EventOverrideRemote,
        remoteSnap: EventOverrideRemote
    ) -> EventOverrideRemote {
        var out = base
        // “notes” double-edit fallback: append sections
        if localSnap.notes != baseSnap.notes && remoteSnap.notes != baseSnap.notes {
            let ln = localSnap.notes ?? ""
            let rn = remoteSnap.notes ?? ""
            out.notes = ln.isEmpty ? rn : (rn.isEmpty ? ln : ln + "\n----\n" + rn)
        } else if overlay.notes != base.notes {
            out.notes = overlay.notes
        }

        // Straight copy for other fields decided by JSON merge
        if overlay.eventId != base.eventId { out.eventId = overlay.eventId }
        if overlay.occurrenceDate != base.occurrenceDate { out.occurrenceDate = overlay.occurrenceDate }
        if overlay.overriddenTitle != base.overriddenTitle { out.overriddenTitle = overlay.overriddenTitle }
        if overlay.overriddenStartDate != base.overriddenStartDate { out.overriddenStartDate = overlay.overriddenStartDate }
        if overlay.overriddenEndDate != base.overriddenEndDate { out.overriddenEndDate = overlay.overriddenEndDate }
        if overlay.overriddenLocation != base.overriddenLocation { out.overriddenLocation = overlay.overriddenLocation }
        if overlay.isCancelled != base.isCancelled { out.isCancelled = overlay.isCancelled }
        if overlay.notes != base.notes { out.notes = overlay.notes }
        if overlay.color != base.color { out.color = overlay.color }   // server likely re-parented
        if overlay.deletedAt != base.deletedAt { out.deletedAt = overlay.deletedAt }
        return out
    }
}
