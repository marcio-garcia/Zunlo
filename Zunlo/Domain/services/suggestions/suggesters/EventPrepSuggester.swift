//
//  EventPrepSuggester.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

public struct EventPrepSuggester: AISuggester {
    private let tools: AIToolRunner
    init(tools: AIToolRunner) { self.tools = tools }

    public func suggest(context: AIContext) -> AISuggestion? {
        guard let next = context.nextEventStart else { return nil }
        // Offer prep if the next event is within 2h and we have at least a 20 min window before it
        guard let pre = context.freeWindows.first(where: { $0.end <= next && $0.duration >= 20 * 60 }) else { return nil }
        
        let title  = "Prep for your next event"
        let detail = "Use \(pre.end.timeIntervalSince(pre.start)/60) min before \(next.formattedDate(dateFormat: .time))."
        let reason = "A little prep reduces stress."

        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: "Add prep tasks") {
                    Task { try await tools.addPrepTasksForNextEvent(prepTemplate: PrepPackTemplate()) }
                },
                AISuggestionCTA(title: "Block prep") {
                    let mins = max(20, Int(pre.duration / 60))
                    Task { try await tools.bookSlot(at: pre.start, minutes: mins, title: "Prep") }
                }
            ],
            telemetryKey: "event_prep",
            score: 84
        )
    }
}
