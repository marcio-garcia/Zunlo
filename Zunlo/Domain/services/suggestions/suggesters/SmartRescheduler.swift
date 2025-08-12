//
//  SmartRescheduler.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

//SmartRescheduler stays generic (real conflict resolution is repo-specific); CTA hooks where you’ll call your resolver.
public struct SmartRescheduler: AISuggester {
    public init() {}
    public func suggest(context: AIContext) -> AISuggestion? {
        guard context.conflictingItemsCount > 0 else { return nil }

        // In v1 we don't compute the specific item here (repo logic is app-specific).
        // The CTA should trigger your real resolver pipeline.
        let title  = "Fix \(context.conflictingItemsCount) conflict(s)"
        let detail = "Move the lowest-priority item to the next clean slot today."
        let reason = "Calendar conflicts detected."

        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: "Resolve now") {
                    // resolver.resolveConflictsToday()
                    // 1) Identify conflict set
                    // 2) Pick lowest priority/flexible item
                    // 3) Move to earliest free window that fits
                }
            ],
            telemetryKey: "smart_rescheduler",
            score: 97
        )
    }
}
