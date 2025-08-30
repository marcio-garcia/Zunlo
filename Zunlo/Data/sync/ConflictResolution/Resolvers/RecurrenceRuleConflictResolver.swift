//
//  RecurrenceRuleConflictResolver.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

final class RecurrenceRuleConflictResolver: AnyConflictResolver {
    let table = "recurrence_rules"
    private let api: SyncAPI

    init(api: SyncAPI) {
        self.api = api
    }

    func attemptAutoResolve(conflict: ConflictData, db: ConflictDB) async {
        do {
            let remote: RecurrenceRuleRemote = try decodeJSON(conflict.remoteJSON ?? "{}", as: RecurrenceRuleRemote.self)
            let local: RecurrenceRuleRemote  = try decodeJSON(conflict.localJSON, as: RecurrenceRuleRemote.self)
            let base: RecurrenceRuleRemote   = try {
                if let b = conflict.baseJSON { return try decodeJSON(b, as: RecurrenceRuleRemote.self) }
                return remote
            }()

            // JSON 3-way with rule invariants
            let structural: Set<String> = ["event_id"]
            let serverOwned: Set<String> = ["created_at", "updated_at", "version"]
            // If both changed, **prefer server** on anchor/truncation fields; otherwise newer-wins
            let anchorPreferServer: Set<String> = ["until", "count", "dtstart"]
            let newerWins: Set<String> = ["by_day", "by_month_day", "by_month", "interval", "wkst", "tzid", "by_set_pos"]

            var mergedObj = json3WayMerge(
                base: toObject(conflict.baseJSON ?? conflict.remoteJSON ?? "{}"),
                local: toObject(conflict.localJSON),
                remote: toObject(conflict.remoteJSON ?? "{}"),
                structuralKeys: structural,
                serverOwnedKeys: serverOwned,
                newerWinsKeys: newerWins,
                localUpdatedAtISO: local.updatedAtRaw,
                remoteUpdatedAtISO: remote.updatedAtRaw
            )

            // Ensure server wins on anchors if both changed
            for k in anchorPreferServer { mergedObj[k] = toObject(conflict.remoteJSON ?? "{}")[k] ?? mergedObj[k] }

            let mergedJSON = toJSON(mergedObj)
            var merged = remote
            let partial: RecurrenceRuleRemote = try decodeJSON(mergedJSON, as: RecurrenceRuleRemote.self)
            merged = overlayRule(base: remote, overlay: partial)

            let expected = remote.version ?? -1
            if let updated = try await api.updateRecRuleIfVersionMatchesPatch(
                id: merged.id,
                expectedVersion: expected,
                patch: RecRuleUpdatePayload.full(from: merged)
            ) {
                try await db.applyRemoteRecurrenceRules([updated])
                try await db.resolveConflict(conflictId: conflict.id, strategy: .autoMerged)
            } else {
                try await db.setConflictNeedsUser(conflictId: conflict.id, reason: "Version changed during rule merge")
            }
        } catch {
            try? await db.failConflict(conflictId: conflict.id, error: error)
        }
    }

    private func overlayRule(base: RecurrenceRuleRemote, overlay: RecurrenceRuleRemote) -> RecurrenceRuleRemote {
        var out = base
        // Copy over fields if changed (adjust names to your model)
        if overlay.eventId != base.eventId { out.eventId = overlay.eventId }
        if overlay.freq != base.freq { out.freq = overlay.freq }
        if overlay.interval != base.interval { out.interval = overlay.interval }
        if overlay.byweekday != base.byweekday { out.byweekday = overlay.byweekday }
        if overlay.bymonthday != base.bymonthday { out.bymonthday = overlay.bymonthday }
        if overlay.bymonth != base.bymonth { out.bymonth = overlay.bymonth }
        if overlay.until != base.until { out.until = overlay.until }
        if overlay.count != base.count { out.count = overlay.count }
        if overlay.deletedAt != base.deletedAt { out.deletedAt = overlay.deletedAt }
        return out
    }
}
