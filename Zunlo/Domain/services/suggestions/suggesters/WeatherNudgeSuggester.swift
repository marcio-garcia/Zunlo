//
//  WeatherNudgeSuggester.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

public struct WeatherNudgeSuggester: AISuggester {
    private let tools: AIToolRunner
    init(tools: AIToolRunner) { self.tools = tools }

    public func suggest(context: AIContext) -> AISuggestion? {
        guard context.isRainingSoon else { return nil }
        let title  = "Rain soon—move errands earlier?"
        let detail = context.weatherSummary ?? "Rain likely in the next hours."
        let reason = "Adjust schedule to weather."

        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: "Shift errands") {
                    Task { try await tools.shiftErrandsEarlierToday() }
                }
            ],
            telemetryKey: "weather_nudge",
            score: 78
        )
    }
}
