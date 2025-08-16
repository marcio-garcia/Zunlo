//
//  DayPlannerSuggester.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

import Foundation

struct DayPlannerSuggester: AICoolDownSuggester {
    private let tools: AIToolRunner
    var usage: SuggestionUsageStore
    var cooldown: TimeInterval
    var maxPenalty: Int

    init(
        tools: AIToolRunner,
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
        let hasWork = context.dueTodayCount > 0 || !context.topUnscheduledTasks.isEmpty
        guard hasWork else { return nil }

        let telemetryKey = "day_planner"
        let baseScore = 95
        let adjusted = usage.adjustedScore(
            base: baseScore,
            maxPenalty: maxPenalty,
            cooldown: cooldown,
            telemetryKey: telemetryKey,
            now: context.now
        )

        let title  = String(localized: "Plan my day")
        let detail = String(localized: "You have \(context.dueTodayCount) task(s) due today, \(context.overdueCount) overdue.")
        let reason = String(localized: "Daily plan reduces context switching.")

        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: String(localized: "Create plan")) {
                    Task {
                        do {
                            try await tools.startDailyPlan(context: context)
                            usage.recordSuccess(forTelemetryKey: telemetryKey, at: Date())
                        } catch {
                            print("DayPlannerSuggester plan CTA failed")
                        }
                    }
                }
            ],
            telemetryKey: telemetryKey,
            score: adjusted
        )
    }
}
