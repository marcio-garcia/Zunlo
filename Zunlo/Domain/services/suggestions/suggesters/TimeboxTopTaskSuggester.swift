//
//  TimeboxTopTaskSuggester.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

import Foundation

struct TimeboxTopTaskSuggester: AICoolDownSuggester {
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
        guard let win = context.nextWindow, let task = context.bestCandidateForNextWindow else { return nil }
        let dur = context.bestFocusDuration()
        let title  = String(localized: "Timebox “\(task.title)”")
        let detail = String(localized: "Use the next free block at \(win.start.formatted(date: .omitted, time: .shortened)).")
        let reason = String(localized: "Timeboxing improves completion odds.")

        let telemetryKey = "timebox_top_task"
        let baseScore = 90
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
                AISuggestionCTA(title: String(localized: "Block \(dur)m")) { store in
                    let runID = store.start(kind: .aiTool(name: "ResolveNow"), status: String(localized: "Preparing…"))
                    Task { @MainActor in
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            try await tools.createFocusBlock(start: win.start, minutes: dur, suggestedTask: task)
                            usage.recordSuccess(forTelemetryKey: telemetryKey, at: Date())
                            store.finish(runID, outcome: .toast(String(localized: "Conflicts resolved"), duration: 3))
                        } catch {
                            store.fail(runID, error: error.localizedDescription)
                        }
                    }
                },
                AISuggestionCTA(title: String(localized: "Split 2×30m")) { store in
                    let runID = store.start(kind: .aiTool(name: "ResolveNow"), status: String(localized: "Preparing…"))
                    Task { @MainActor in
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            // Optionally book two blocks (simplified: one now)
                            try await tools.createFocusBlock(start: win.start, minutes: 30, suggestedTask: task)
                            usage.recordSuccess(forTelemetryKey: telemetryKey, at: Date())
                            store.finish(runID, outcome: .toast(String(localized: "Conflicts resolved"), duration: 3))
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
