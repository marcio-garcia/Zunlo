//
//  QuickAddSuggester.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

//QuickAddSuggester uses period to tailor the copy.
struct QuickAddSuggester: AICoolDownSuggester {
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
        let targetTime: String
        switch context.period {
        case .evening:     targetTime = String(localized: "6 pm")
        case .morning:     targetTime = String(localized: "10 am")
        case .afternoon:   targetTime = String(localized: "3 pm")
        case .earlyMorning:targetTime = String(localized: "today")
        case .lateNight:   targetTime = String(localized: "tomorrow morning")
        }

        let title  = String(localized: "Add a quick task")
        let detail = String(localized: "Try “Buy gift for Ana • \(targetTime) • High”.")
        let reason = String(localized: "Fast capture reduces mental load.")

        let telemetryKey = "quick_add"
        let baseScore = 70
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
                AISuggestionCTA(title: String(localized: "Add task")) { store in
                    let runID = store.start(kind: .aiTool(name: "AddTask"), status: String(localized: "Preparing…"))
                    Task { @MainActor in
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            // nav.presentQuickAdd(prefill: "Buy gift for Ana at \(targetTime) • High")
                            store.finish(runID, outcome: .toast(String(localized: "Start now"), duration: 3))
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
