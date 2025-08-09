//
//  OverdueTriage.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

public struct OverdueTriage: AISuggester {
    public init() {}
    public func suggest(context: AIContext) -> AISuggestion? {
        guard context.overdueCount >= 2 else { return nil }
        let title = "Clear 2 overdue in 15 minutes?"
        let detail = "Quick wins reduce today’s pressure."
        let reason = "You have \(context.overdueCount) overdue tasks."
        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: "Start 15‑min blitz") {
                    // Start short focus with auto-pick of two smallest tasks
                },
                AISuggestionCTA(title: "Move 2 to tomorrow") {
                    // Bulk reschedule lowest priority overdue → tomorrow morning
                }
            ],
            telemetryKey: "overdue_triage",
            score: 90
        )
    }
}
