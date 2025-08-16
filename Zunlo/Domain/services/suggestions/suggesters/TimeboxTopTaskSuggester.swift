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
        let title  = "Timebox “\(task.title)”"
        let detail = "Use the next free block at \(win.start.formatted(date: .omitted, time: .shortened))."
        let reason = "Timeboxing improves completion odds."

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
                AISuggestionCTA(title: "Block \(dur)m") {
                    Task {
                        do {
                            try await tools.createFocusBlock(start: win.start, minutes: dur, suggestedTask: task)
                            usage.recordSuccess(forTelemetryKey: telemetryKey, at: Date())
                        } catch {
                            print("TimeboxTopTaskSuggester Block CTA failed")
                        }
                    }
                },
                AISuggestionCTA(title: "Split 2×30m") {
                    Task {
                        do {
                            // Optionally book two blocks (simplified: one now)
                            try await tools.createFocusBlock(start: win.start, minutes: 30, suggestedTask: task)
                            usage.recordSuccess(forTelemetryKey: telemetryKey, at: Date())
                        } catch {
                            print("TimeboxTopTaskSuggester Split CTA failed")
                        }
                    }
                }
            ],
            telemetryKey: "timebox_top_task",
            score: adjusted
        )
    }
}
