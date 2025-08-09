//
//  SmartRescheduler.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

public struct SmartRescheduler: AISuggester {
    public init() {}
    public func suggest(context: AIContext) -> AISuggestion? {
        guard context.conflictingItemsCount > 0 else { return nil }
        let title = "Fix \(context.conflictingItemsCount) conflict(s)"
        let detail = "I’ll move the lowest‑priority item to the next clean slot."
        let reason = "Calendar conflicts detected today."
        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: "Resolve now") {
                    // Implement: find conflict, shift lowest-priority by nearest free slot
                }
            ],
            telemetryKey: "smart_rescheduler",
            score: 95
        )
    }
}
