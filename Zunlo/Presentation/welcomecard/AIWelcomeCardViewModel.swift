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

//    private let time: TimeProvider
//    private let policyProvider: SuggestionPolicyProvider
//    private let tasksEngine: TaskSuggestionEngine
//    private let eventsEngine: EventSuggestionEngine
    private let aiToolRunner: AIToolRunner
//    private let weather: WeatherProvider?
    private let context: AIContext

    init(context: AIContext,
//        time: TimeProvider,
//        policyProvider: SuggestionPolicyProvider,
//        tasksEngine: TaskSuggestionEngine,
//        eventsEngine: EventSuggestionEngine,
        aiToolRunner: AIToolRunner
//        weather: WeatherProvider?
    ) {
//        self.time = time
//        self.policyProvider = policyProvider
//        self.tasksEngine = tasksEngine
//        self.eventsEngine = eventsEngine
        self.aiToolRunner = aiToolRunner
//        self.weather = weather
        self.context = context
    }

    public func load() {
        isLoading = true
        Task {
            // Build context (you already have the builder)
//            let ctx = await AIContextBuilder().build(
//                time: SystemTimeProvider(),
//                policyProvider: policyProvider,
//                tasks: tasksEngine,
//                events: eventsEngine,
//                weather: weather,
//                on: Date()
//            )
            
            let engine = makeDefaultSuggestionEngine(tools: aiToolRunner)
            let ranked = engine.run(context: context)
            self.suggestions = ranked
            self.isLoading = false
            // Telemetry: view impression can be sent here with top suggestion key
        }
    }
    
    func makeDefaultSuggestionEngine(tools: AIToolRunner) -> AISuggestionEngine {
        let usageStore = DefaultsSuggestionUsageStore()
        return AISuggestionEngine(suggesters: [
            // Yours
            GapPlanner(tools: tools, usage: usageStore),
            OverdueTriage(tools: tools, usage: usageStore),
            SmartRescheduler(tools: tools, usage: usageStore),
            QuickAddSuggester(tools: tools, usage: usageStore),
            // New
            DayPlannerSuggester(tools: tools, usage: usageStore),
            TimeboxTopTaskSuggester(tools: tools, usage: usageStore),
            FindSlotSuggester(minutes: 30, tools: tools, usage: usageStore),
            WeatherNudgeSuggester(tools: tools, usage: usageStore),
            EventPrepSuggester(tools: tools, usage: usageStore),
            RoutineSuggester(tools: tools, usage: usageStore)
        ])
    }
}
