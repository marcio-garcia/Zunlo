//
//  OverdueTriage.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

//OverdueTriage shows the two top overdue candidates as bullets and offers concrete CTAs.
struct OverdueTriage: AICoolDownSuggester {
    private let tools: AIToolRunner
    var usage: SuggestionUsageStore
    var cooldown: TimeInterval
    var maxPenalty: Int
    
    init(tools: AIToolRunner,
         usage: SuggestionUsageStore,
         cooldownHours: Double = 6,
         maxPenalty: Int = 60
    ) {
        self.tools = tools
        self.usage = usage
        self.cooldown = cooldownHours * 3600
        self.maxPenalty = maxPenalty
    }
    
    public func suggest(context: AIContext) -> AISuggestion? {
        guard context.overdueCount >= 2 else { return nil }

        // Prefer overdue tasks if present, else fallback to ranked top.
        let overdue = context.rankedCandidates.filter { ($0.dueDate ?? .distantFuture) < context.now }
        let picks = overdue.isEmpty ? Array(context.rankedCandidates.prefix(2))
                                    : Array(overdue.prefix(2))
        guard !picks.isEmpty else { return nil }

        let title  = String(localized: "Clear 2 overdue in 15 minutes?")
        let bullet = picks.map { "• \($0.title)" }.joined(separator: "\n")
        let detail = String(localized: "Quick wins reduce today's pressure:\n\(bullet)")
        let reason = String(localized: "You have \(context.overdueCount) overdue tasks.")

        let telemetryKey = "overdue_triage"
        let baseScore = 92
        let adjusted = usage.adjustedScore(
            base: baseScore,
            maxPenalty: maxPenalty,
            cooldown: cooldown,
            telemetryKey: telemetryKey,
            now: context.now
        )
        
        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: String(localized: "Start 15-min blitz")) { store in
                    let runID = store.start(kind: .aiTool(name: "StartBlitz"), status: String(localized: "Preparing…"))
                    Task { @MainActor in
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            // focus.runBlitz(tasks: picks, minutes: 15)
                            store.finish(runID, outcome: .toast(String(localized: "Start now"), duration: 3))
                        } catch {
                            store.fail(runID, error: error.localizedDescription)
                        }
                    }
                },
                AISuggestionCTA(title: String(localized: "Move to tomorrow")) { store in
                    let runID = store.start(kind: .aiTool(name: "MoveToTomorrow"), status: String(localized: "Preparing…"))
                    Task { @MainActor in
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            // rescheduler.bulkMoveToTomorrowMorning(picks)
                            store.finish(runID, outcome: .toast(String(localized: "Start now"), duration: 3))
                        } catch {
                            store.fail(runID, error: error.localizedDescription)
                        }
                    }
                }
            ],
            telemetryKey: telemetryKey,
            score: adjusted
        )
    }
}
