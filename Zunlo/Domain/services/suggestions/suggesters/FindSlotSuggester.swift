//
//  FindSlotSuggester.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

import Foundation

public struct FindSlotSuggester: AISuggester {
    private let tools: AIToolRunner
    private let minutes: Int
    init(minutes: Int = 30, tools: AIToolRunner) {
        self.minutes = minutes; self.tools = tools
    }

    public func suggest(context: AIContext) -> AISuggestion? {
        guard let win = context.freeWindows.first(where: { $0.duration >= TimeInterval(minutes * 60) }) else {
            return nil
        }
        let title  = "Find \(minutes)-min slot"
        let detail = "Free at \(win.start.formatted(date: .omitted, time: .shortened))."
        let reason = "Short focus beats none."

        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: "Book it") {
                    Task { try await tools.bookSlot(at: win.start, minutes: minutes, title: "Focus") }
                }
            ],
            telemetryKey: "find_slot",
            score: 80
        )
    }
}
