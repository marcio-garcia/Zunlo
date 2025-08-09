//
//  GapPlanner.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

public struct GapPlanner: AISuggester {
    public init() {}
    public func suggest(context: AIContext) -> AISuggestion? {
        guard let window = context.freeWindows.first(where: { $0.start > context.now && $0.duration >= 30*60 }) else {
            return nil
        }
        let minutes = Int(window.duration / 60)
        let title = "Free \(minutes)-min window coming up"
        let detail = "Perfect for 1 focused task before your next event."
        let reason = "Detected a free block starting \(window.start.formatted(date: .omitted, time: .shortened))."
        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: "Start \(min(minutes, 45))-min Focus") {
                    // Hook into your focus/session start
                    // e.g., nav.presentFocusTimer(length: min(minutes, 45))
                },
                AISuggestionCTA(title: "Schedule top task") {
                    // e.g., schedule context.topUnscheduledTasks.first into window
                }
            ],
            telemetryKey: "gap_planner",
            score: 80
        )
    }
}
