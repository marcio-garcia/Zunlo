//
//  FindSlotSuggester.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

import Foundation

struct FindSlotSuggester: AICoolDownSuggester {
    private let tools: AIToolRunner
    var usage: SuggestionUsageStore
    var cooldown: TimeInterval
    var maxPenalty: Int
    private let minutes: Int

    init(minutes: Int = 30,
         tools: AIToolRunner,
         usage: SuggestionUsageStore,
         cooldownHours: Double = 6,
         maxPenalty: Int = 60
    ) {
        self.minutes = minutes
        self.tools = tools
        self.usage = usage
        self.cooldown = cooldownHours * 3600
        self.maxPenalty = maxPenalty
    }

    public func suggest(context: AIContext) -> AISuggestion? {
        guard let win = context.freeWindows.first(where: { $0.duration >= TimeInterval(minutes * 60) }) else {
            return nil
        }
        
        let telemetryKey = "find_slot"
        let baseScore = 80
        let adjusted = usage.adjustedScore(
            base: baseScore,
            maxPenalty: maxPenalty,
            cooldown: cooldown,
            telemetryKey: telemetryKey,
            now: context.now
        )
        
        let title  = "Find \(minutes)-min slot"
        let detail = "Free at \(win.start.formatted(date: .omitted, time: .shortened))."
        let reason = "Short focus beats none."

        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: String(localized: "Book it")) { store in
                    let runID = store.start(kind: .aiTool(name: "BookSlot"), status: String(localized: "Preparing…"))
                    Task { @MainActor in
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            try await tools.bookSlot(at: win.start, minutes: minutes, title: String(localized: "Focus"))
                            store.finish(runID, outcome: .toast(String(localized: "Slot booked"), duration: 3))
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
