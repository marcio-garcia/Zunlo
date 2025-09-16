//
//  IntentInterpreter.swift
//  SmartParseKit
//
//  Created by Claude on 9/15/25.
//

import Foundation

public final class IntentInterpreter {

    public init() {}

    /// Classifies user intent based on metadata and temporal tokens using comprehensive scoring
    /// Returns either a definitive intent or multiple predictions for ambiguous cases
    public func classify(metadataTokens: [MetadataToken], temporalTokens: [TemporalToken]) -> IntentAmbiguity {

        // Score all possible intents based on available evidence
        var intentScores: [Intent: Double] = [:]

        // Initialize all intent scores to 0
        let allIntents: [Intent] = [.createTask, .createEvent, .rescheduleTask, .rescheduleEvent,
                                   .updateTask, .updateEvent, .cancelTask, .cancelEvent, .view, .plan, .unknown]
        allIntents.forEach { intentScores[$0] = 0.0 }

        // Score based on temporal context
        scoreTemporalContext(temporalTokens: temporalTokens, scores: &intentScores)

        // Score based on metadata context
        scoreMetadataContext(metadataTokens: metadataTokens, scores: &intentScores)

        // Score based on entity type indicators
        scoreEntityTypeIndicators(metadataTokens: metadataTokens, temporalTokens: temporalTokens, scores: &intentScores)

        // Convert scores to predictions with reasoning
        let predictions = createPredictionsFromScores(intentScores, metadataTokens: metadataTokens, temporalTokens: temporalTokens)

        return IntentAmbiguity(predictions: predictions)
    }

    // MARK: - Scoring Methods

    private func scoreTemporalContext(temporalTokens: [TemporalToken], scores: inout [Intent: Double]) {
        guard !temporalTokens.isEmpty else { return }

        for token in temporalTokens {
            switch token.kind {
            case .timeRange:
                // Time ranges strongly suggest Events (startDate/endDate)
                scores[.createEvent]! += 3.0
                scores[.rescheduleEvent]! += 2.5
                scores[.updateEvent]! += 2.0
                // Tasks can have dueDates but ranges are less common
                scores[.createTask]! += 1.0
                scores[.rescheduleTask]! += 0.8

            case .absoluteTime:
                // Absolute times favor Events (scheduled meetings, appointments)
                scores[.createEvent]! += 2.5
                scores[.rescheduleEvent]! += 2.0
                scores[.updateEvent]! += 1.5
                // Tasks with specific times are possible but less common
                scores[.createTask]! += 1.2
                scores[.rescheduleTask]! += 1.0

            case .relativeDay(.tomorrow), .relativeWeek(.nextWeek), .weekend(.nextWeek):
                // Future references suggest creation
                scores[.createEvent]! += 2.0
                scores[.createTask]! += 2.0

            case .relativeDay(.today), .relativeWeek(.thisWeek), .weekend(.thisWeek):
                // Current references could be updates or rescheduling
                scores[.updateEvent]! += 1.5
                scores[.updateTask]! += 1.5
                scores[.rescheduleEvent]! += 1.0
                scores[.rescheduleTask]! += 1.0

            case .weekday(_, let modifier):
                if modifier == .next {
                    // Future weekday - likely creation
                    scores[.createEvent]! += 1.8
                    scores[.createTask]! += 1.5
                } else {
                    // Existing weekday - could be rescheduling
                    scores[.rescheduleEvent]! += 1.5
                    scores[.rescheduleTask]! += 1.2
                }

            default:
                // Generic temporal context
                scores[.createEvent]! += 1.0
                scores[.createTask]! += 1.0
            }
        }
    }

    private func scoreMetadataContext(metadataTokens: [MetadataToken], scores: inout [Intent: Double]) {
        for token in metadataTokens {
            switch token.kind {
            case .tag:
                // Tags are primary UserTask feature
                scores[.createTask]! += 2.5
                scores[.updateTask]! += 2.0
                scores[.rescheduleTask]! += 1.5
                // Events don't typically use tags
                scores[.createEvent]! += 0.5
                scores[.updateEvent]! += 0.3

            case .priority:
                // Priority is exclusive UserTask feature
                scores[.createTask]! += 3.0
                scores[.updateTask]! += 2.5
                scores[.rescheduleTask]! += 2.0
                // Events don't have priority

            case .location:
                // Location is primary Event feature
                scores[.createEvent]! += 2.5
                scores[.updateEvent]! += 2.0
                scores[.rescheduleEvent]! += 1.5
                // Tasks can have location but it's less common
                scores[.createTask]! += 0.8
                scores[.updateTask]! += 0.6

            case .reminder:
                // Both Events and Tasks support reminders, slight Event preference
                scores[.createEvent]! += 1.5
                scores[.createTask]! += 1.3
                scores[.updateEvent]! += 1.2
                scores[.updateTask]! += 1.0

            case .notes:
                // Both support notes equally
                scores[.createEvent]! += 1.0
                scores[.createTask]! += 1.0
                scores[.updateEvent]! += 0.8
                scores[.updateTask]! += 0.8
            }
        }
    }

    private func scoreEntityTypeIndicators(metadataTokens: [MetadataToken], temporalTokens: [TemporalToken], scores: inout [Intent: Double]) {

        // Analyze patterns that indicate completion/cancellation
        var hasCompletionIndicators = false
        var hasCancellationIndicators = false

        // Since we don't have title text, look for completion patterns in other metadata
        for token in metadataTokens {
            switch token.kind {
            case .tag(let name, _):
                let lowercased = name.lowercased()
                if lowercased.contains("done") || lowercased.contains("complete") ||
                   lowercased.contains("finished") || lowercased.contains("concluído") ||
                   lowercased.contains("terminado") || lowercased.contains("finalizado") {
                    hasCompletionIndicators = true
                }
                if lowercased.contains("cancel") || lowercased.contains("delete") ||
                   lowercased.contains("remove") || lowercased.contains("cancelar") ||
                   lowercased.contains("eliminar") || lowercased.contains("remover") {
                    hasCancellationIndicators = true
                }
            case .notes(let content, _):
                let lowercased = content.lowercased()
                if lowercased.contains("mark as done") || lowercased.contains("completed") ||
                   lowercased.contains("finished") || lowercased.contains("marcar como concluído") {
                    hasCompletionIndicators = true
                }
                if lowercased.contains("cancel") || lowercased.contains("delete") ||
                   lowercased.contains("cancelar") || lowercased.contains("deletar") {
                    hasCancellationIndicators = true
                }
            default:
                break
            }
        }

        if hasCompletionIndicators {
            // Tasks are more commonly "completed", Events are more commonly "attended"
            scores[.cancelTask]! += 2.5  // Tasks are "completed"
            scores[.cancelEvent]! += 1.0  // Events might be "finished"
        }

        if hasCancellationIndicators {
            // Both can be cancelled, slight Event preference for explicit cancellation
            scores[.cancelEvent]! += 2.0
            scores[.cancelTask]! += 1.8
        }

        // If no temporal context but has metadata, favor viewing/updating
        if temporalTokens.isEmpty && !metadataTokens.isEmpty {
            scores[.view]! += 2.0
            scores[.updateEvent]! += 1.0
            scores[.updateTask]! += 1.0
        }

        // If only temporal context, favor creation
        if !temporalTokens.isEmpty && metadataTokens.isEmpty {
            scores[.createEvent]! += 1.5
            scores[.createTask]! += 1.2
        }
    }

    private func createPredictionsFromScores(_ intentScores: [Intent: Double], metadataTokens: [MetadataToken], temporalTokens: [TemporalToken]) -> [IntentPrediction] {

        // Filter out intents with zero scores and sort by score
        let scoredIntents = intentScores
            .filter { $0.value > 0.0 }
            .sorted { $0.value > $1.value }

        guard !scoredIntents.isEmpty else {
            // Fallback if no scores - default to view with low confidence
            return [IntentPrediction(intent: .view, confidence: 0.3, reasoning: ["No clear intent indicators - defaulting to view"])]
        }

        let maxScore = scoredIntents.first!.value
        var predictions: [IntentPrediction] = []

        for (intent, score) in scoredIntents {
            // Convert score to confidence (0.0 to 1.0)
            // Use exponential scaling to emphasize clear winners
            let confidence = Float(min(1.0, score / max(10.0, maxScore)))

            // Only include predictions with meaningful confidence
            if confidence >= 0.2 {
                let reasoning = generateReasoning(for: intent, score: score, metadataTokens: metadataTokens, temporalTokens: temporalTokens)
                predictions.append(IntentPrediction(intent: intent, confidence: confidence, reasoning: reasoning))
            }

            // Limit to top 3 predictions to avoid overwhelming the user
            if predictions.count >= 3 {
                break
            }
        }

        return predictions
    }

    private func generateReasoning(for intent: Intent, score: Double, metadataTokens: [MetadataToken], temporalTokens: [TemporalToken]) -> [String] {
        var reasoning: [String] = []

        // Add temporal reasoning
        if !temporalTokens.isEmpty {
            let hasTimeRanges = temporalTokens.contains { if case .timeRange = $0.kind { return true }; return false }
            let hasAbsoluteTimes = temporalTokens.contains { if case .absoluteTime = $0.kind { return true }; return false }
            let hasFutureRefs = temporalTokens.contains {
                switch $0.kind {
                case .relativeDay(.tomorrow), .relativeWeek(.nextWeek), .weekend(.nextWeek): return true
                case .weekday(_, .next): return true
                default: return false
                }
            }

            if hasTimeRanges && (intent == .createEvent || intent == .rescheduleEvent) {
                reasoning.append("Time ranges strongly indicate event scheduling")
            }
            if hasAbsoluteTimes && isEventIntent(intent) {
                reasoning.append("Absolute times favor event operations")
            }
            if hasFutureRefs && (intent == .createEvent || intent == .createTask) {
                reasoning.append("Future references suggest creation")
            }
        }

        // Add metadata reasoning
        let hasLocation = metadataTokens.contains { if case .location = $0.kind { return true }; return false }
        let hasPriority = metadataTokens.contains { if case .priority = $0.kind { return true }; return false }
        let hasTags = metadataTokens.contains { if case .tag = $0.kind { return true }; return false }

        if hasLocation && isEventIntent(intent) {
            reasoning.append("Location metadata indicates event operation")
        }
        if hasPriority && isTaskIntent(intent) {
            reasoning.append("Priority metadata indicates task operation")
        }
        if hasTags && isTaskIntent(intent) {
            reasoning.append("Tags strongly indicate task operation")
        }

        // Add score-based reasoning
        reasoning.append("Score: \(String(format: "%.1f", score))")

        return reasoning
    }

    // MARK: - Helper Methods

    private func isEventIntent(_ intent: Intent) -> Bool {
        switch intent {
        case .createEvent, .rescheduleEvent, .updateEvent, .cancelEvent:
            return true
        default:
            return false
        }
    }

    private func isTaskIntent(_ intent: Intent) -> Bool {
        switch intent {
        case .createTask, .rescheduleTask, .updateTask, .cancelTask:
            return true
        default:
            return false
        }
    }
}

// MARK: - Supporting Types

private struct EntityType {
    var isEvent = false
    var isTask = false
}