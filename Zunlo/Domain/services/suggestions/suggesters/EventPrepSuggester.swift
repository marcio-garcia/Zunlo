//
//  EventPrepSuggester.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

import Foundation

struct EventPrepSuggester: AICoolDownSuggester {
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
        guard let next = context.nextEventStart else { return nil }
        // Offer prep if the next event is within 2h and we have at least a 20 min window before it
        guard let pre = context.freeWindows.first(where: { $0.end <= next && $0.duration >= 20 * 60 }) else { return nil }
        
        let telemetryKey = "event_prep"
        let baseScore = 84
        let adjusted = usage.adjustedScore(
            base: baseScore,
            maxPenalty: maxPenalty,
            cooldown: cooldown,
            telemetryKey: telemetryKey,
            now: context.now
        )
        
        let title  = String(localized: "Prep for your next event")
        let detail = String(localized: "Use \(pre.end.timeIntervalSince(pre.start)/60) min before \(next.formattedDate(dateFormat: .time)).")
        let reason = String(localized: "A little prep reduces stress.")

        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: String(localized: "Add prep tasks")) { store in
                    let runID = store.start(kind: .aiTool(name: "AddPrepTasks"), status: String(localized: "Preparing event…"))
                    Task { @MainActor in
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            try await tools.addPrepTasksForNextEvent(prepTemplate: PrepPackTemplate())
                            store.finish(runID, outcome: .toast(String(localized: "Prep added"), duration: 3))
                        } catch {
                            store.fail(runID, error: error.localizedDescription)
                        }
                    }
                },
                AISuggestionCTA(title: String(localized: "Block prep")) { store in
                    let runID = store.start(kind: .aiTool(name: "BlockPrep"), status: String(localized: "Preparing block…"))
                    let mins = max(20, Int(pre.duration / 60))
                    Task { @MainActor in
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            try await tools.bookSlot(at: pre.start, minutes: mins, title: String(localized: "Prep"))
                            store.finish(runID, outcome: .toast(String(localized: "Prep block added"), duration: 3))
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
