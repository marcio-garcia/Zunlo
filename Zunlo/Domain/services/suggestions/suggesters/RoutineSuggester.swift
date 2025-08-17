//
//  RoutineSuggester.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

import Foundation

struct RoutineSuggester: AICoolDownSuggester {
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
        switch context.period {
        case .morning, .earlyMorning:
            let telemetryKey = "routine_morning"
            let baseScore = 82
            let adjusted = usage.adjustedScore(
                base: baseScore,
                maxPenalty: maxPenalty,
                cooldown: cooldown,
                telemetryKey: telemetryKey,
                now: context.now
            )
            return AISuggestion(
                title: String(localized: "Kick off your day"),
                detail: String(localized: "Pick 3 priorities and block the first focus"),
                reason: String(localized: "Morning clarity improves throughput"),
                ctas: [AISuggestionCTA(title: String(localized: "Start daily plan")) { store in
                    let runID = store.start(kind: .aiTool(name: "StartDailyPlan"), status: String(localized: "Preparing…"))
                    Task {
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            try await tools.startDailyPlan(context: context)
                            store.finish(runID, outcome: .toast(String(localized: "Focus block created"), duration: 3))
                        } catch {
                            store.fail(runID, error: error.localizedDescription)
                        }
                    }
                }],
                telemetryKey: telemetryKey,
                score: adjusted
            )
        case .afternoon:
            let telemetryKey = "routine_midday"
            let baseScore = 76
            let adjusted = usage.adjustedScore(
                base: baseScore,
                maxPenalty: maxPenalty,
                cooldown: cooldown,
                telemetryKey: telemetryKey,
                now: context.now
            )
            return AISuggestion(
                title: String(localized: "Midday checkpoint"),
                detail: String(localized: "Running behind? Shift one long block"),
                reason: String(localized: "Replan to stay realistic"),
                ctas: [AISuggestionCTA(title: String(localized: "Resolve conflicts")) { store in
                    let runID = store.start(kind: .aiTool(name: "ResolveConflicts"), status: String(localized: "Preparing…"))
                    Task {
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            try await tools.resolveConflictsToday()
                            store.finish(runID, outcome: .toast(String(localized: "Conflicts resolved"), duration: 3))
                        } catch {
                            store.fail(runID, error: error.localizedDescription)
                        }
                    }
                }],
                telemetryKey: telemetryKey,
                score: adjusted
            )
        case .evening, .lateNight:
            let telemetryKey = "routine_evening"
            let baseScore = 79
            let adjusted = usage.adjustedScore(
                base: baseScore,
                maxPenalty: maxPenalty,
                cooldown: cooldown,
                telemetryKey: telemetryKey,
                now: context.now
            )
            return AISuggestion(
                title: String(localized: "Evening wrap"),
                detail: String(localized: "Log wins, roll unfinished to tomorrow"),
                reason: String(localized: "Clean closure lowers stress"),
                ctas: [AISuggestionCTA(title: "Start wrap") { store in
                    let runID = store.start(kind: .aiTool(name: "ResolveConflicts"), status: String(localized: "Preparing…"))
                    Task {
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            try await tools.startEveningWrap()
                            store.finish(runID, outcome: .toast(String(localized: "Conflicts resolved"), duration: 3))
                        } catch {
                            store.fail(runID, error: error.localizedDescription)
                        }
                    }
                }],
                telemetryKey: telemetryKey,
                score: adjusted
            )
        }
    }
}
