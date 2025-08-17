//
//  WeatherNudgeSuggester.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

import Foundation

struct WeatherNudgeSuggester: AICoolDownSuggester {
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
        guard context.isRainingSoon else { return nil }
        let title  = "Rain soon—move errands earlier?"
        let detail = context.weatherSummary ?? "Rain likely in the next hours"
        let reason = "Adjust schedule to weather"

        let telemetryKey = "weather_nudge"
        let baseScore = 78
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
                AISuggestionCTA(title: String(localized: "Shift errands")) { store in
                    let runID = store.start(kind: .aiTool(name: "ShiftErrands"), status: String(localized: "Preparing…"))
                    Task { @MainActor in
                        do {
                            store.progress(runID, status: String(localized: "Working…"), fraction: 0.2)
                            try await tools.shiftErrandsEarlierToday()
                            usage.recordSuccess(forTelemetryKey: telemetryKey, at: Date())
                            store.finish(runID, outcome: .toast(String(localized: "Errands shifted"), duration: 3))
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
