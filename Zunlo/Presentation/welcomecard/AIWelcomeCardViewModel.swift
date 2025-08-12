//
//  AIWelcomeCardViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

@MainActor
public final class AIWelcomeCardViewModel: ObservableObject {
    @Published public private(set) var suggestions: [AISuggestion] = []
    @Published public private(set) var isLoading = false

    private let time: TimeProvider
    private let tasksEngine: TaskSuggestionEngine
    private let eventsEngine: EventSuggestionEngine
    private let weather: WeatherProvider?

    private let suggesters: [AISuggester]

    init(
        time: TimeProvider,
        tasksEngine: TaskSuggestionEngine,
        eventsEngine: EventSuggestionEngine,
        weather: WeatherProvider?,
        suggesters: [AISuggester] = [GapPlanner(), OverdueTriage(), SmartRescheduler(), QuickAddSuggester()]
    ) {
        self.time = time
        self.tasksEngine = tasksEngine
        self.eventsEngine = eventsEngine
        self.weather = weather
        self.suggesters = suggesters
    }

    public func load() {
        isLoading = true
        Task {
            let ctx = await AIContextBuilder.build(time: time, tasks: tasksEngine, events: eventsEngine, weather: weather)
            let produced = suggesters.compactMap { $0.suggest(context: ctx) }
            // Simple rank: higher score first, tie-break by telemetry key for stability
            let ranked = produced.sorted { ($0.score, $0.telemetryKey) > ($1.score, $1.telemetryKey) }
            self.suggestions = ranked
            self.isLoading = false
            // Telemetry: view impression can be sent here with top suggestion key
        }
    }
}
