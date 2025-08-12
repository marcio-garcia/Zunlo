//
//  GapPlanner.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

//GapPlanner proposes a focus block and (if available) suggests the top candidate’s title.
public struct GapPlanner: AISuggester {
    public init() {}
    public func suggest(context: AIContext) -> AISuggestion? {
        guard let window = context.nextWindow else { return nil }
        // guard against micro-intervals (your freeWindows is already ≥10m, but safe)
        guard window.duration >= 10 * 60 else { return nil }

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
                AISuggestionCTA(title: "Start \(focusMin)-min Focus") {
                    // presentFocusTimer(length: focusMin, suggestedTask: candidate)
                },
                AISuggestionCTA(title: "Schedule top task") {
                    // if let t = candidate { scheduler.schedule(t, at: window.start, durationMinutes: focusMin) }
                }
            ],
            telemetryKey: "gap_planner",
            score: 85
        )
    }
}
