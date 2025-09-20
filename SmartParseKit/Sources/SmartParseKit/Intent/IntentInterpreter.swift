//
//  IntentInterpreter.swift
//  SmartParseKit
//
//  Created by Claude on 9/15/25.
//

import Foundation

public final class IntentInterpreter {

    public init() {}

    /// Classifies user intent based on input text, metadata and temporal tokens using comprehensive scoring
    /// Returns either a definitive intent or multiple predictions for ambiguous cases
    public func classify(inputText: String, metadataTokens: [MetadataToken], temporalTokens: [TemporalToken], languagePack: DateLanguagePack) -> IntentAmbiguity {

        // Score all possible intents based on available evidence
        var intentScores: [Intent: Double] = [:]

        // Initialize all intent scores to 0
        let allIntents: [Intent] = [.createTask, .createEvent, .rescheduleTask, .rescheduleEvent,
                                   .updateTask, .updateEvent, .cancelTask, .cancelEvent, .view, .plan, .unknown]
        allIntents.forEach { intentScores[$0] = 0.0 }

        // Score based on command patterns in input text (highest priority)
        scoreCommandPatterns(inputText: inputText, languagePack: languagePack, scores: &intentScores)

        // Score based on temporal context
        scoreTemporalContext(temporalTokens: temporalTokens, scores: &intentScores)

        // Score based on metadata context
        scoreMetadataContext(metadataTokens: metadataTokens, scores: &intentScores)

        // Score based on entity type indicators
//        scoreEntityTypeIndicators(metadataTokens: metadataTokens, temporalTokens: temporalTokens, scores: &intentScores)

        // Convert scores to predictions with reasoning
        let predictions = createPredictionsFromScores(intentScores, inputText: inputText, metadataTokens: metadataTokens, temporalTokens: temporalTokens)

        return IntentAmbiguity(predictions: predictions)
    }

    // MARK: - Scoring Methods

    private func scoreCommandPatterns(inputText: String, languagePack: DateLanguagePack, scores: inout [Intent: Double]) {
        let lowercased = inputText.lowercased()
        let range = NSRange(lowercased.startIndex..., in: lowercased)

        // Metadata addition patterns (highest priority - 6.0+)
        // These should override general create patterns when adding metadata to existing items
        if languagePack.metadataAdditionWithPrepositionRegex().firstMatch(in: lowercased, range: range) != nil
            || languagePack.metadataAdditionDirectRegex().firstMatch(in: lowercased, range: range) != nil {
            scores[.updateEvent]! += 6.0
            scores[.updateTask]! += 6.0
        }

        // Specific intent patterns (highest scores - 5.0+)
        // These are very explicit and should override other signals

        if languagePack.intentCreateTaskRegex().firstMatch(in: lowercased, range: range) != nil {
            scores[.createTask]! += 5.0
        }

        if languagePack.intentCreateEventRegex().firstMatch(in: lowercased, range: range) != nil {
            scores[.createEvent]! += 5.0
        }

//        if languagePack.intentCancelTaskRegex().firstMatch(in: lowercased, range: range) != nil {
//            scores[.cancelTask]! += 5.0
//        }
//
//        if languagePack.intentCancelEventRegex().firstMatch(in: lowercased, range: range) != nil {
//            scores[.cancelEvent]! += 5.0
//        }

        // General intent patterns (high scores - 4.0+)
        // These indicate action type but not entity type

//        if languagePack.intentCreateRegex().firstMatch(in: lowercased, range: range) != nil {
//            scores[.createEvent]! += 4.0
//            scores[.createTask]! += 4.0
//        }

        if languagePack.intentRescheduleRegex().firstMatch(in: lowercased, range: range) != nil {
            scores[.rescheduleEvent]! += 5.0
            scores[.rescheduleTask]! += 5.0
        }

        if languagePack.intentCancelRegex().firstMatch(in: lowercased, range: range) != nil {
            scores[.cancelEvent]! += 5.0
            scores[.cancelTask]! += 5.0
        }

        if languagePack.intentUpdateRegex().firstMatch(in: lowercased, range: range) != nil {
            scores[.updateEvent]! += 5.0
            scores[.updateTask]! += 5.0
        }

        if languagePack.intentViewRegex().firstMatch(in: lowercased, range: range) != nil {
            scores[.view]! += 4.5
        }

        if languagePack.intentPlanRegex().firstMatch(in: lowercased, range: range) != nil {
            scores[.plan]! += 4.5
        }

        // Entity type keywords (moderate scores - 2.0+)
        // These help distinguish between tasks and events when action is ambiguous

        if languagePack.taskKeywordsRegex().firstMatch(in: lowercased, range: range) != nil {
            scores[.createTask]! += 2.5
            scores[.updateTask]! += 2.0
            scores[.rescheduleTask]! += 2.0
            scores[.cancelTask]! += 2.0
        }

        if languagePack.eventKeywordsRegex().firstMatch(in: lowercased, range: range) != nil {
            scores[.createEvent]! += 2.5
            scores[.updateEvent]! += 2.0
            scores[.rescheduleEvent]! += 2.0
            scores[.cancelEvent]! += 2.0
        }
    }

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
//                scores[.createTask]! += 1.0
//                scores[.rescheduleTask]! += 0.8

            case .absoluteTime:
                // Absolute times favor Events (scheduled meetings, appointments)
                scores[.createEvent]! += 2.5
                scores[.rescheduleEvent]! += 2.0
                scores[.updateEvent]! += 1.5
                
            case .absoluteDate:
                // Absolute date favor Events and Tasks equaly as tasks can have dueDatas
                scores[.createEvent]! += 1.0
                scores[.rescheduleEvent]! += 1.0
                scores[.updateEvent]! += 1.0
                // Tasks with specific times are possible but less common
                scores[.createTask]! += 1.0
                scores[.rescheduleTask]! += 1.0
                scores[.updateTask]! += 1.0

            case .relativeDay(.tomorrow), .relativeWeek(.nextWeek), .weekend(.nextWeek):
                // Future references suggest creation or rescheduling
                scores[.createEvent]! += 2.0
                scores[.rescheduleEvent]! += 2.0
                scores[.createTask]! += 1.5
                scores[.rescheduleTask]! += 1.5

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

            default: break
                // Generic temporal context
//                scores[.createEvent]! += 1.0
//                scores[.createTask]! += 1.0
            }
        }
    }

    private func scoreMetadataContext(metadataTokens: [MetadataToken], scores: inout [Intent: Double]) {
        for token in metadataTokens {
            switch token.kind {
            case .newTitle:
                scores[.updateTask]! += 3.0
                scores[.updateEvent]! += 3.0

            case .tag:
                // Tags are primary UserTask feature
                scores[.createTask]! += 2.0
                scores[.updateTask]! += 3.0
                scores[.rescheduleTask]! += 1.5
                // Events don't typically use tags
//                scores[.createEvent]! += 0.5
//                scores[.updateEvent]! += 0.3

            case .priority:
                // Priority is exclusive UserTask feature
                scores[.createTask]! += 2.0
                scores[.updateTask]! += 3.0
                scores[.rescheduleTask]! += 2.0
                // Events don't have priority

            case .location:
                // Location is primary Event feature
                scores[.createEvent]! += 2.0
                scores[.updateEvent]! += 3.0
                scores[.rescheduleEvent]! += 1.5
                // Tasks can have location but it's less common
//                scores[.createTask]! += 0.8
//                scores[.updateTask]! += 0.6

            case .reminder:
                // Both Events and Tasks support reminders, slight Event preference
                scores[.createEvent]! += 1.5
                scores[.createTask]! += 1.2
                scores[.updateEvent]! += 2.5
                scores[.updateTask]! += 2.0

            case .notes:
                // Both support notes equally
//                scores[.createEvent]! += 1.0
//                scores[.updateEvent]! += 0.8
                scores[.createTask]! += 0.5
                scores[.updateTask]! += 2.0
            }
        }
    }

//    private func scoreEntityTypeIndicators(metadataTokens: [MetadataToken], temporalTokens: [TemporalToken], scores: inout [Intent: Double]) {
//
//        // Analyze patterns that indicate completion/cancellation
//        var hasCompletionIndicators = false
//        var hasCancellationIndicators = false
//
//        // Since we don't have title text, look for completion patterns in other metadata
//        for token in metadataTokens {
//            switch token.kind {
//            case .tag(let name, _):
//                let lowercased = name.lowercased()
//                if lowercased.contains("done") || lowercased.contains("complete") ||
//                   lowercased.contains("finished") || lowercased.contains("concluído") ||
//                   lowercased.contains("terminado") || lowercased.contains("finalizado") {
//                    hasCompletionIndicators = true
//                }
//                if lowercased.contains("cancel") || lowercased.contains("delete") ||
//                   lowercased.contains("remove") || lowercased.contains("cancelar") ||
//                   lowercased.contains("eliminar") || lowercased.contains("remover") {
//                    hasCancellationIndicators = true
//                }
//            case .notes(let content, _):
//                let lowercased = content.lowercased()
//                if lowercased.contains("mark as done") || lowercased.contains("completed") ||
//                   lowercased.contains("finished") || lowercased.contains("marcar como concluído") {
//                    hasCompletionIndicators = true
//                }
//                if lowercased.contains("cancel") || lowercased.contains("delete") ||
//                   lowercased.contains("cancelar") || lowercased.contains("deletar") {
//                    hasCancellationIndicators = true
//                }
//            default:
//                break
//            }
//        }
//
//        if hasCompletionIndicators {
//            // Tasks are more commonly "completed", Events are more commonly "attended"
//            scores[.cancelTask]! += 2.5  // Tasks are "completed"
//            scores[.cancelEvent]! += 1.0  // Events might be "finished"
//        }
//
//        if hasCancellationIndicators {
//            // Both can be cancelled, slight Event preference for explicit cancellation
//            scores[.cancelEvent]! += 2.0
//            scores[.cancelTask]! += 1.8
//        }
//
//        // If no temporal context but has metadata, favor viewing/updating
//        if temporalTokens.isEmpty && !metadataTokens.isEmpty {
//            scores[.view]! += 2.0
//            scores[.updateEvent]! += 1.0
//            scores[.updateTask]! += 1.0
//        }
//
//        // If only temporal context, favor creation
//        if !temporalTokens.isEmpty && metadataTokens.isEmpty {
//            scores[.createEvent]! += 1.5
//            scores[.createTask]! += 1.2
//        }
//    }

    private func createPredictionsFromScores(_ intentScores: [Intent: Double], inputText: String, metadataTokens: [MetadataToken], temporalTokens: [TemporalToken]) -> [IntentPrediction] {

//        // Check for mixed language indicators that should create ambiguity
//        let mixedLanguageAdjustment = detectMixedLanguageAmbiguity(inputText: inputText)
//
//        // Check for complex metadata without clear verbs that should create ambiguity
//        let complexMetadataAmbiguity = detectComplexMetadataAmbiguity(inputText: inputText, metadataTokens: metadataTokens)

        // Filter out intents with zero scores and sort by score
        let scoredIntents = intentScores
            .filter { $0.value > 0.0 }
            .sorted { $0.value > $1.value }

        guard !scoredIntents.isEmpty else {
            return [IntentPrediction(id: UUID(), intent: .unknown, confidence: 0.1, reasoning: ["No clear intent indicators"])]
        }

        let maxScore = scoredIntents.first!.value
        var predictions: [IntentPrediction] = []

//        // For inputs that should be ambiguous (mixed language or complex metadata without verbs), add multiple similar predictions
//        if (mixedLanguageAdjustment > 0 || complexMetadataAmbiguity) && scoredIntents.count >= 1 {
//            // Add the top intent with reduced confidence
//            let (topIntent, topScore) = scoredIntents[0]
//            let topConfidence = Float(min(0.7, topScore / max(10.0, maxScore)))
//            var topReasoning = generateReasoning(for: topIntent, score: topScore, inputText: inputText, metadataTokens: metadataTokens, temporalTokens: temporalTokens)
//            if mixedLanguageAdjustment > 0 {
//                topReasoning.insert("Mixed language input detected", at: 0)
//            }
//            if complexMetadataAmbiguity {
//                topReasoning.insert("Complex metadata without clear command verb", at: 0)
//            }
//            predictions.append(IntentPrediction(intent: topIntent, confidence: topConfidence, reasoning: topReasoning))
//
//            // Add alternative intent with similar confidence to create ambiguity
//            let alternativeIntent: Intent = topIntent == .createTask ? .createEvent : .createTask
//            let alternativeConfidence = Float(max(0.4, topConfidence - 0.2))
//            var alternativeReasoning = ["Alternative interpretation possible"]
//            if mixedLanguageAdjustment > 0 {
//                alternativeReasoning.insert("Mixed language input creates uncertainty", at: 0)
//            }
//            if complexMetadataAmbiguity {
//                alternativeReasoning.insert("Unclear intent with multiple metadata types", at: 0)
//            }
//            predictions.append(IntentPrediction(intent: alternativeIntent, confidence: alternativeConfidence, reasoning: alternativeReasoning))
//        } else {
            // Normal processing for non-mixed language inputs
            for (intent, score) in scoredIntents {
                // Convert score to confidence (0.0 to 1.0)
                // Use exponential scaling to emphasize clear winners
                let confidence = Float(min(1.0, score / max(10.0, maxScore)))

                // Only include predictions with meaningful confidence
                if confidence >= 0.2 {
                    let reasoning = generateReasoning(for: intent, score: score, inputText: inputText, metadataTokens: metadataTokens, temporalTokens: temporalTokens)
                    predictions.append(IntentPrediction(id: UUID(), intent: intent, confidence: confidence, reasoning: reasoning))
                }

                // Limit to top 3 predictions to avoid overwhelming the user
                if predictions.count >= 3 {
                    break
                }
            }
//        }

        return predictions
    }

    private func generateReasoning(for intent: Intent, score: Double, inputText: String, metadataTokens: [MetadataToken], temporalTokens: [TemporalToken]) -> [String] {
        var reasoning: [String] = []

        // Add command pattern reasoning (most important)
        if score >= 5.0 {
            reasoning.append("Explicit command pattern detected in input")
        } else if score >= 4.0 {
            reasoning.append("Strong command indicator found in input")
        }

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

    private func detectMixedLanguageAmbiguity(inputText: String) -> Float {
        let words = inputText.lowercased().components(separatedBy: .whitespacesAndNewlines)

        // English indicators
        let englishWords = Set(["add", "create", "schedule", "book", "set", "update", "modify", "cancel", "delete", "remove", "show", "view", "at", "on", "in", "to", "for", "and", "or", "the", "a", "an", "tag", "priority", "reminder", "note", "location", "high", "low", "medium", "urgent", "important", "work", "meeting", "event", "task", "today", "tomorrow", "yesterday", "next", "this", "before", "after", "minutes", "hours", "days", "weeks", "months"])

        // Portuguese indicators
        let portugueseWords = Set(["adicionar", "criar", "agendar", "marcar", "definir", "atualizar", "modificar", "cancelar", "deletar", "remover", "mostrar", "ver", "em", "na", "no", "para", "com", "e", "ou", "o", "a", "os", "as", "tag", "prioridade", "lembrete", "nota", "localização", "local", "alta", "baixa", "média", "urgente", "importante", "trabalho", "reunião", "evento", "tarefa", "hoje", "amanhã", "ontem", "próximo", "próxima", "antes", "depois", "minutos", "horas", "dias", "semanas", "meses"])

        // Spanish indicators
        let spanishWords = Set(["añadir", "crear", "programar", "reservar", "establecer", "actualizar", "modificar", "cancelar", "eliminar", "quitar", "mostrar", "ver", "en", "el", "la", "los", "las", "para", "con", "y", "o", "el", "la", "un", "una", "etiqueta", "prioridad", "recordatorio", "nota", "ubicación", "alto", "bajo", "medio", "urgente", "importante", "trabajo", "reunión", "evento", "tarea", "hoy", "mañana", "ayer", "próximo", "próxima", "antes", "después", "minutos", "horas", "días", "semanas", "meses"])

        var languageCount = 0

        let englishMatches = words.filter { englishWords.contains($0) }.count
        let portugueseMatches = words.filter { portugueseWords.contains($0) }.count
        let spanishMatches = words.filter { spanishWords.contains($0) }.count

        if englishMatches > 0 { languageCount += 1 }
        if portugueseMatches > 0 { languageCount += 1 }
        if spanishMatches > 0 { languageCount += 1 }

        // Return ambiguity factor if mixed languages detected
        return languageCount > 1 ? Float(languageCount) * 0.3 : 0.0
    }

    private func detectComplexMetadataAmbiguity(inputText: String, metadataTokens: [MetadataToken]) -> Bool {
        // Check if we have multiple metadata types but no clear command verbs
        let words = inputText.lowercased().components(separatedBy: .whitespacesAndNewlines)

        // Clear command verbs that indicate definitive intent
        let clearCommandVerbs = Set(["add", "create", "schedule", "book", "set", "update", "modify", "cancel", "delete", "remove", "show", "view", "plan", "organize"])

        let hasClearchVerb = words.contains { clearCommandVerbs.contains($0) }

        // Count metadata types
        var metadataTypeCount = 0
        var hasTag = false
        var hasPriority = false
        var hasReminder = false
        var hasLocation = false
        var hasNotes = false

        for token in metadataTokens {
            switch token.kind {
            case .tag:
                if !hasTag { hasTag = true; metadataTypeCount += 1 }
            case .priority:
                if !hasPriority { hasPriority = true; metadataTypeCount += 1 }
            case .reminder:
                if !hasReminder { hasReminder = true; metadataTypeCount += 1 }
            case .location:
                if !hasLocation { hasLocation = true; metadataTypeCount += 1 }
            case .notes:
                if !hasNotes { hasNotes = true; metadataTypeCount += 1 }
            default:
                break
            }
        }

        // Also check for metadata words in the input even if tokens weren't extracted
        let metadataWords = ["priority", "tag", "reminder", "remind", "location", "note", "notes", "high", "low", "medium", "urgent", "important"]
        let metadataWordCount = words.filter { metadataWords.contains($0) }.count

        // Ambiguous if we have multiple metadata indicators but no clear command verb
        return (metadataTypeCount >= 2 || metadataWordCount >= 2) && !hasClearchVerb
    }
}

// MARK: - Supporting Types

private struct EntityType {
    var isEvent = false
    var isTask = false
}
