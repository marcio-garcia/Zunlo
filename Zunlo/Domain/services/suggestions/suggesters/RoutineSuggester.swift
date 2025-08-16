//
//  RoutineSuggester.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

public struct RoutineSuggester: AISuggester {
    private let tools: AIToolRunner
    init(tools: AIToolRunner) { self.tools = tools }

    public func suggest(context: AIContext) -> AISuggestion? {
        switch context.period {
        case .morning, .earlyMorning:
            return AISuggestion(
                title: "Kick off your day",
                detail: "Pick 3 priorities and block the first focus.",
                reason: "Morning clarity improves throughput.",
                ctas: [AISuggestionCTA(title: "Start daily plan") {
                    Task { try await tools.startDailyPlan(context: context) }
                }],
                telemetryKey: "routine_morning",
                score: 82
            )
        case .afternoon:
            return AISuggestion(
                title: "Midday checkpoint",
                detail: "Running behind? Shift one long block.",
                reason: "Replan to stay realistic.",
                ctas: [AISuggestionCTA(title: "Resolve conflicts") {
                    Task { try await tools.resolveConflictsToday() }
                }],
                telemetryKey: "routine_midday",
                score: 76
            )
        case .evening, .lateNight:
            return AISuggestion(
                title: "Evening wrap",
                detail: "Log wins, roll unfinished to tomorrow.",
                reason: "Clean closure lowers stress.",
                ctas: [AISuggestionCTA(title: "Start wrap") {
                    Task { try await tools.startEveningWrap() }
                }],
                telemetryKey: "routine_evening",
                score: 79
            )
        }
    }
}
