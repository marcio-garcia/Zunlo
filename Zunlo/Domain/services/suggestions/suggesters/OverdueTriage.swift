//
//  OverdueTriage.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

//OverdueTriage shows the two top overdue candidates as bullets and offers concrete CTAs.
public struct OverdueTriage: AISuggester {
    public init() {}
    public func suggest(context: AIContext) -> AISuggestion? {
        guard context.overdueCount >= 2 else { return nil }

        // Prefer overdue tasks if present, else fallback to ranked top.
        let overdue = context.rankedCandidates.filter { ($0.dueDate ?? .distantFuture) < context.now }
        let picks = overdue.isEmpty ? Array(context.rankedCandidates.prefix(2))
                                    : Array(overdue.prefix(2))
        guard !picks.isEmpty else { return nil }

        let title  = "Clear 2 overdue in 15 minutes?"
        let bullet = picks.map { "• \($0.title)" }.joined(separator: "\n")
        let detail = "Quick wins reduce today's pressure:\n\(bullet)"
        let reason = "You have \(context.overdueCount) overdue tasks."

        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: "Start 15-min blitz") {
                    // focus.runBlitz(tasks: picks, minutes: 15)
                },
                AISuggestionCTA(title: "Move 2 to tomorrow") {
                    // rescheduler.bulkMoveToTomorrowMorning(picks)
                }
            ],
            telemetryKey: "overdue_triage",
            score: 92
        )
    }
}
