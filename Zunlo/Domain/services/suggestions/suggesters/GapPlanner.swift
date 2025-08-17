//
//  GapPlanner.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

//GapPlanner proposes a focus block and (if available) suggests the top candidate’s title.
struct GapPlanner: AICoolDownSuggester {
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
        guard let window = context.nextWindow else { return nil }
        // guard against micro-intervals (your freeWindows is already ≥10m, but safe)
        guard window.duration >= 10 * 60 else { return nil }

        let telemetryKey = "gap_planner"
        let baseScore = 85
        let adjusted = usage.adjustedScore(
            base: baseScore,
            maxPenalty: maxPenalty,
            cooldown: cooldown,
            telemetryKey: telemetryKey,
            now: context.now
        )
        
        let focusMin = context.bestFocusDuration()
        let candidate = context.bestCandidateForNextWindow
        let durationText = window.duration.formatHM()
        
        let title  = "Focus \(focusMin) min at \(window.start.formatted(date: .omitted, time: .shortened))"
        let detail = candidate != nil
            ? "Good \(durationText) free block. Start with “\(candidate!.title)”."
            : "Good \(durationText) free block."
        let reason = "Detected a free window starting \(window.start.formatted(date: .omitted, time: .shortened))."

        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: String(localized: "Start \(focusMin)-min Focus")) { store in
                    let runID = store.start(kind: .aiTool(name: "StartFocus"), status: String(localized: "Preparing…"))
                    Task { @MainActor in
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            // presentFocusTimer(length: focusMin, suggestedTask: candidate)
                            store.finish(runID, outcome: .toast("Focus booked", duration: 3))
                        } catch {
                            store.fail(runID, error: error.localizedDescription)
                        }
                    }
                },
                AISuggestionCTA(title: String(localized: "Schedule top task")) { store in
                    let runID = store.start(kind: .aiTool(name: "TopTask"), status: String(localized: "Preparing…"))
                    Task { @MainActor in
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            // if let t = candidate { scheduler.schedule(t, at: window.start, durationMinutes: focusMin) }
                            store.finish(runID, outcome: .toast("Task booked", duration: 3))
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
