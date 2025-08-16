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
    private let policyProvider: SuggestionPolicyProvider
    private let tasksEngine: TaskSuggestionEngine
    private let eventsEngine: EventSuggestionEngine
    private let aiToolRunner: AIToolRunner
    private let weather: WeatherProvider?

    private let suggesters: [AISuggester]

    init(
        time: TimeProvider,
        policyProvider: SuggestionPolicyProvider,
        tasksEngine: TaskSuggestionEngine,
        eventsEngine: EventSuggestionEngine,
        aiToolRunner: AIToolRunner,
        weather: WeatherProvider?,
        suggesters: [AISuggester] = [GapPlanner(), OverdueTriage(), SmartRescheduler(), QuickAddSuggester()]
    ) {
        self.time = time
        self.policyProvider = policyProvider
        self.tasksEngine = tasksEngine
        self.eventsEngine = eventsEngine
        self.aiToolRunner = aiToolRunner
        self.weather = weather
        self.suggesters = suggesters
    }

    public func load() {
        isLoading = true
        Task {
            // Build context (you already have the builder)
            let ctx = await AIContextBuilder.build(
                time: SystemTimeProvider(),
                policyProcider: policyProvider,
                tasks: tasksEngine,
                events: eventsEngine,
                weather: weather
            )
            
            let engine = makeDefaultSuggestionEngine(tools: aiToolRunner)
            let ranked = engine.run(context: ctx)
            // → Render as chips/cards, and wire CTAs (already call tools)
            
//            let ctx = await AIContextBuilder.build(
//                time: time,
//                policyProvider: policyProvider,
//                tasks: tasksEngine,
//                events: eventsEngine,
//                weather: weather
//            )
//            let produced = suggesters.compactMap { $0.suggest(context: ctx) }
//            // Simple rank: higher score first, tie-break by telemetry key for stability
//            let ranked = produced.sorted { ($0.score, $0.telemetryKey) > ($1.score, $1.telemetryKey) }
            self.suggestions = ranked
            self.isLoading = false
            // Telemetry: view impression can be sent here with top suggestion key
        }
    }
    
    func makeDefaultSuggestionEngine(tools: AIToolRunner) -> AISuggestionEngine {
        AISuggestionEngine(suggesters: [
            // Yours
            GapPlanner(),
            OverdueTriage(),
            SmartRescheduler(),
            QuickAddSuggester(),
            // New
            DayPlannerSuggester(tools: tools, usage: DefaultsSuggestionUsageStore()),
            TimeboxTopTaskSuggester(tools: tools, usage: DefaultsSuggestionUsageStore()),
            FindSlotSuggester(minutes: 30, tools: tools),
            WeatherNudgeSuggester(tools: tools),
            EventPrepSuggester(tools: tools),
            RoutineSuggester(tools: tools)
        ])
    }
}
