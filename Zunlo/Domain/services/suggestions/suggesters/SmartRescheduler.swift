//
//  SmartRescheduler.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

//SmartRescheduler stays generic (real conflict resolution is repo-specific); CTA hooks where you’ll call your resolver.
struct SmartRescheduler: AICoolDownSuggester {
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
        guard context.conflictingItemsCount > 0 else { return nil }

        // In v1 we don't compute the specific item here (repo logic is app-specific).
        // The CTA should trigger your real resolver pipeline.
        let title  = String(localized: "Fix \(context.conflictingItemsCount) conflict(s)")
        let detail = String(localized: "Move the lowest-priority item to the next clean slot today")
        let reason = String(localized: "Calendar conflicts detected")

        let telemetryKey = "smart_rescheduler"
        let baseScore = 97
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
                AISuggestionCTA(title: String(localized: "Resolve now")) { store in
                    let runID = store.start(kind: .aiTool(name: "ResolveNow"), status: String(localized: "Preparing…"))
                    Task { @MainActor in
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            // resolver.resolveConflictsToday()
                            // 1) Identify conflict set
                            // 2) Pick lowest priority/flexible item
                            // 3) Move to earliest free window that fits
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
