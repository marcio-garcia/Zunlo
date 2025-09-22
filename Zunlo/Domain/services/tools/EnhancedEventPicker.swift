import Foundation
import SmartParseKit

// MARK: - Enhanced Event Candidate Picker

/// Represents a candidate selection with confidence metrics
struct CandidateSelection<T> {
    let single: T?
    let alternatives: [T]
    let confidence: SelectionConfidence
    let reasoning: SelectionReasoning
}

/// Confidence levels for candidate selection
enum SelectionConfidence {
    case high       // Very confident in single selection
    case medium     // Moderately confident, but worth showing alternatives
    case low        // Low confidence, definitely need user input
    case ambiguous  // Multiple equally valid candidates
}

/// Reasoning behind the selection decision
struct SelectionReasoning {
    let primaryFactor: String      // What drove the selection
    let scoreGap: Double          // Gap between top candidates
    let totalCandidates: Int      // How many candidates were considered
    let topScores: [Double]       // Top 3 scores for analysis
}

/// Enhanced scoring factors for event matching
struct EventScore {
    let title: Double           // Title similarity
    let temporal: Double        // Time proximity
    let contextual: Double      // Contextual factors
    let behavioral: Double      // User behavior patterns
    let semantic: Double        // Semantic understanding
    let total: Double          // Combined score
}

/// Enhanced event candidate picker
class EnhancedEventPicker {
    private let calendar: Calendar
    private let userPreferences: UserPreferences

    init(calendar: Calendar, userPreferences: UserPreferences = .default) {
        self.calendar = calendar
        self.userPreferences = userPreferences
    }

    /// Main entry point for enhanced candidate selection
    func selectEventCandidate(
        from events: [EventOccurrence],
        for command: CommandContext,
        intent: Intent,
        referenceDate: Date,
        searchWindow: DateInterval? = nil
    ) -> CandidateSelection<EventOccurrence> {

        // 1. Score all candidates with enhanced metrics
        let scoredCandidates = scoreEventCandidates(events, for: command, intent: intent, referenceDate: referenceDate, searchWindow: searchWindow)

        // 2. Apply intent-specific filtering and weighting
//        let filtered = applyIntentSpecificFiltering(scoredCandidates, intent: intent, command: command, referenceDate: referenceDate)

        // 3. Intelligent selection with confidence assessment
        return makeIntelligentSelection(scoredCandidates, command: command, intent: intent)
    }

    // MARK: - Enhanced Scoring

    private func scoreEventCandidates(
        _ events: [EventOccurrence],
        for command: CommandContext,
        intent: Intent,
        referenceDate: Date,
        searchWindow: DateInterval?
    ) -> [ScoredCandidate<EventOccurrence>] {

        return events.compactMap { event in
            let score = calculateEnhancedScore(event: event, command: command, intent: intent, referenceDate: referenceDate, searchWindow: searchWindow)
            return ScoredCandidate(candidate: event, score: score)
        }.sorted { $0.score.total > $1.score.total }
    }

    private func calculateEnhancedScore(
        event: EventOccurrence,
        command: CommandContext,
        intent: Intent,
        referenceDate: Date,
        searchWindow: DateInterval?
    ) -> EventScore {

        // 1. Title/Text Similarity (enhanced with semantic understanding)
        let titleScore = enhancedTitleScore(
            query: command.title,
            eventTitle: event.title,
            intent: intent
        )

        // 2. Temporal Relevance (context-aware)
        let temporalScore = enhancedTemporalScore(
            event: event,
            command: command,
            intent: intent,
            referenceDate: referenceDate,
            searchWindow: searchWindow
        )

        // 3. Contextual Factors
        let contextualScore = calculateContextualScore(
            event: event,
            command: command,
            intent: intent
        )

        // 4. Behavioral Patterns
        let behavioralScore = calculateBehavioralScore(
            event: event,
            command: command,
            intent: intent
        )

        // 5. Semantic Understanding
        let semanticScore = calculateSemanticScore(
            event: event,
            command: command,
            intent: intent
        )

        // 6. Combine with intent-specific weights
        let weights = getIntentSpecificWeights(intent)
        let total = (titleScore * weights.title +
                    temporalScore * weights.temporal +
                    contextualScore * weights.contextual +
                    behavioralScore * weights.behavioral +
                    semanticScore * weights.semantic)

        return EventScore(
            title: titleScore,
            temporal: temporalScore,
            contextual: contextualScore,
            behavioral: behavioralScore,
            semantic: semanticScore,
            total: total
        )
    }

    // MARK: - Enhanced Title Scoring

    private func enhancedTitleScore(query: String, eventTitle: String, intent: Intent) -> Double {
        guard !query.isEmpty && !eventTitle.isEmpty else { return 0.0 }

        let normalizedQuery = normalize(query, locale: calendar.locale ?? .current)
        let normalizedTitle = normalize(eventTitle, locale: calendar.locale ?? .current)

        // 1. Exact match bonus
        if query.lowercased() == eventTitle.lowercased() {
            return 1.0
        }

        // 2. Substring matching
        let substringScore = calculateSubstringScore(normalizedQuery, normalizedTitle)

        // 3. Word overlap (existing Jaccard similarity)
        let wordOverlapScore = calculateWordOverlapScore(normalizedQuery, normalizedTitle)

        // 4. Fuzzy matching for typos
        let fuzzyScore = calculateFuzzyScore(query, eventTitle)

        // 5. Keyword importance weighting
        let keywordScore = calculateKeywordScore(normalizedQuery, normalizedTitle, intent: intent)

        // Combine scores with weights
        return max(substringScore * 0.3 + wordOverlapScore * 0.3 + fuzzyScore * 0.2 + keywordScore * 0.2, wordOverlapScore)
    }

    // MARK: - Enhanced Temporal Scoring

    private func enhancedTemporalScore(
        event: EventOccurrence,
        command: CommandContext,
        intent: Intent,
        referenceDate: Date,
        searchWindow: DateInterval?
    ) -> Double {

        // 1. Check if event falls within specified date range (for "hoje", "amanha", etc.)
        let rangeScore = calculateDateRangeScore(event: event, command: command, searchWindow: searchWindow)

        // 2. Base time proximity (for specific times)
        let anchor = command.temporalContext.dateRange?.start ?? command.temporalContext.finalDate
        let proximityScore = calculateTimeProximity(event.startDate, anchor: anchor)

        // Use the better of range score or proximity score
        let baseScore = max(rangeScore, proximityScore)

        // 2. Intent-specific temporal preferences
        let intentModifier = 1.0 // getTemporalModifier(for: intent, event: event, now: referenceDate)

        // 3. Recency bias for certain intents
        let recencyModifier = calculateRecencyModifier(event: event, intent: intent, now: referenceDate)

        // 4. Day-of-week patterns
        let dayPatternModifier = calculateDayPatternModifier(event: event, command: command)

        return baseScore * intentModifier * recencyModifier * dayPatternModifier
    }

    // MARK: - Contextual Scoring

    private func calculateContextualScore(
        event: EventOccurrence,
        command: CommandContext,
        intent: Intent
    ) -> Double {

        var score = 0.5 // Base score

        // 1. Event status relevance
        score *= getStatusRelevance(event: event, intent: intent)

        // 2. Recurrence pattern matching
        if let recurrenceScore = calculateRecurrenceRelevance(event: event, command: command, intent: intent) {
            score *= recurrenceScore
        }

        // 3. Duration appropriateness
        score *= calculateDurationRelevance(event: event, command: command)

        // 4. Location/context tags matching
        score *= calculateLocationContextScore(event: event, command: command)

        return min(1.0, score)
    }

    // MARK: - Behavioral Scoring

    private func calculateBehavioralScore(
        event: EventOccurrence,
        command: CommandContext,
        intent: Intent
    ) -> Double {

        // This would integrate with user behavior analytics
        // For now, return neutral score
        return 0.5
    }

    // MARK: - Semantic Scoring

    private func calculateSemanticScore(
        event: EventOccurrence,
        command: CommandContext,
        intent: Intent
    ) -> Double {

        // 1. Category/type matching
        let categoryScore = calculateCategoryMatch(event: event, command: command)

        // 2. Language/locale considerations
        let localeScore = calculateLocaleRelevance(event: event, command: command)

        return (categoryScore + localeScore) / 2.0
    }

    // MARK: - Intent-Specific Logic

    private func applyIntentSpecificFiltering(
        _ candidates: [ScoredCandidate<EventOccurrence>],
        intent: Intent,
        command: CommandContext,
        referenceDate: Date
    ) -> [ScoredCandidate<EventOccurrence>] {

        switch intent {
        case .cancelEvent:
            // For cancellation, prefer future events and avoid past events
            return candidates.filter { candidate in
                candidate.candidate.startDate > referenceDate.addingTimeInterval(-3600) // Allow 1 hour in past
            }

        case .updateEvent, .rescheduleEvent:
            // For updates/reschedules, include current and future events
            return candidates.filter { candidate in
                candidate.candidate.endDate > referenceDate.addingTimeInterval(-1800) // Allow 30 min in past
            }

        default:
            return candidates
        }
    }

    private func makeIntelligentSelection(
        _ candidates: [ScoredCandidate<EventOccurrence>],
        command: CommandContext,
        intent: Intent
    ) -> CandidateSelection<EventOccurrence> {

        guard !candidates.isEmpty else {
            return CandidateSelection(
                single: nil,
                alternatives: [],
                confidence: .low,
                reasoning: SelectionReasoning(
                    primaryFactor: "No candidates found",
                    scoreGap: 0,
                    totalCandidates: 0,
                    topScores: []
                )
            )
        }

        let topScores = Array(candidates.prefix(3).map { $0.score.total })
        let topScore = topScores.first ?? 0

        // Calculate confidence based on score distribution
        let confidence = calculateSelectionConfidence(scores: topScores, intent: intent)
        let scoreGap = topScores.count > 1 ? topScores[0] - topScores[1] : 1.0

        // Determine selection strategy based on confidence
        switch confidence {
        case .high:
            return CandidateSelection(
                single: candidates.first?.candidate,
                alternatives: [],
                confidence: confidence,
                reasoning: SelectionReasoning(
                    primaryFactor: determinePrimaryFactor(candidates.first?.score),
                    scoreGap: scoreGap,
                    totalCandidates: candidates.count,
                    topScores: topScores
                )
            )

        case .medium:
            return CandidateSelection(
                single: topScore > 0.8 ? candidates.first?.candidate : nil,
                alternatives: Array(candidates.prefix(3).map { $0.candidate }),
                confidence: confidence,
                reasoning: SelectionReasoning(
                    primaryFactor: determinePrimaryFactor(candidates.first?.score),
                    scoreGap: scoreGap,
                    totalCandidates: candidates.count,
                    topScores: topScores
                )
            )

        case .low, .ambiguous:
            return CandidateSelection(
                single: nil,
                alternatives: Array(candidates.prefix(5).map { $0.candidate }),
                confidence: confidence,
                reasoning: SelectionReasoning(
                    primaryFactor: "Multiple similar candidates",
                    scoreGap: scoreGap,
                    totalCandidates: candidates.count,
                    topScores: topScores
                )
            )
        }
    }

    // MARK: - Helper Methods

    private func calculateSelectionConfidence(scores: [Double], intent: Intent) -> SelectionConfidence {
        guard let topScore = scores.first else { return .low }

        if scores.count == 1 {
            // For single candidates, be more generous with confidence
            if topScore > 0.7 {
                return .high
            } else if topScore > 0.4 {
                return .medium
            } else {
                return .low
            }
        }

        let scoreGap = scores[0] - scores[1]

        if topScore > 0.8 && scoreGap > 0.15 {
            return .high
        } else if topScore > 0.5 && scoreGap > 0.1 {
            return .medium
        } else if scoreGap < 0.05 {
            return .ambiguous
        } else {
            return .low
        }
    }

    private func determinePrimaryFactor(_ score: EventScore?) -> String {
        guard let score = score else { return "Unknown" }

        let factors = [
            ("Title Match", score.title),
            ("Time Proximity", score.temporal),
            ("Context", score.contextual),
            ("Behavior", score.behavioral),
            ("Semantic", score.semantic)
        ]

        return factors.max(by: { $0.1 < $1.1 })?.0 ?? "Unknown"
    }
}

// MARK: - Supporting Types

struct ScoredCandidate<T> {
    let candidate: T
    let score: EventScore
}

struct IntentWeights {
    let title: Double
    let temporal: Double
    let contextual: Double
    let behavioral: Double
    let semantic: Double
}

struct UserPreferences {
    let timeToleranceHours: Double
    let preferRecent: Bool
    let languageCode: String

    static let `default` = UserPreferences(
        timeToleranceHours: 0.5,
        preferRecent: true,
        languageCode: "en"
    )
}

// MARK: - Extensions and Helper Functions

extension EnhancedEventPicker {

    private func normalize(_ s: String, locale: Locale) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        // Remove diacritics (á, à, ã, ç, ê, …) and do case-insensitive folding.
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale)
        return folded.components(separatedBy: separators)
                     .filter { !$0.isEmpty }
    }

    private func calculateSubstringScore(_ query: [String], _ title: [String]) -> Double {
        let queryString = query.joined(separator: " ")
        let titleString = title.joined(separator: " ")

        if titleString.contains(queryString) {
            return 0.9
        } else if queryString.contains(titleString) {
            return 0.8
        }
        return 0.0
    }

    private func calculateWordOverlapScore(_ query: [String], _ title: [String]) -> Double {
        let querySet = Set(query)
        let titleSet = Set(title)

        if querySet.isEmpty || titleSet.isEmpty { return 0 }

        let intersection = querySet.intersection(titleSet).count
        let union = querySet.union(titleSet).count

        // Jaccard similarity
        let jaccardScore = Double(intersection) / Double(union)

        // Also calculate how much of the title is covered by the query
        let titleCoverage = titleSet.isEmpty ? 0 : Double(intersection) / Double(titleSet.count)

        // Return the maximum of Jaccard and title coverage for better matching
        return max(jaccardScore, titleCoverage)
    }

    private func calculateFuzzyScore(_ query: String, _ title: String) -> Double {
        // Simple Levenshtein-based fuzzy matching
        let distance = levenshteinDistance(query.lowercased(), title.lowercased())
        let maxLength = max(query.count, title.count)
        return maxLength > 0 ? max(0, 1.0 - Double(distance) / Double(maxLength)) : 0
    }

    private func calculateKeywordScore(_ query: [String], _ title: [String], intent: Intent) -> Double {
        // Weight important keywords based on intent
        let importantKeywords = getImportantKeywords(for: intent)

        var score = 0.0
        for keyword in query {
            if title.contains(keyword) {
                score += importantKeywords.contains(keyword) ? 0.2 : 0.1
            }
        }
        return min(1.0, score)
    }

    private func calculateDateRangeScore(event: EventOccurrence, command: CommandContext, searchWindow: DateInterval?) -> Double {
        var dateRange: DateInterval
        
        if let interval = searchWindow {
            dateRange = interval
        } else {
            let context = command.temporalContext
            let startOfFinalDate = context.finalDate.startOfDay(calendar: calendar)
            var startOfNextDay = startOfFinalDate.startOfNextDay(calendar: calendar)
            startOfNextDay = calendar.date(byAdding: .second, value: -1, to: startOfNextDay) ?? startOfNextDay
            
            dateRange = context.dateRange ?? DateInterval(
                start: startOfFinalDate,
                end: startOfNextDay
            )
        }

        // Check if event overlaps with the specified date range
        let eventStart = event.startDate
        let eventEnd = event.endDate

        // Event overlaps if:
        // 1. Event starts within range, OR
        // 2. Event ends within range, OR
        // 3. Event spans the entire range
        let overlaps = (dateRange.contains(eventStart)) ||
                      (dateRange.contains(eventEnd)) ||
                      (eventStart < dateRange.start && eventEnd > dateRange.end)

        if overlaps {
            // Perfect match for date range queries like "hoje"
            return 1.0
        } else {
            // Calculate proximity to the range
            let distanceToStart = abs(eventStart.timeIntervalSince(dateRange.start)) / 3600.0 // hours
            let distanceToEnd = abs(eventStart.timeIntervalSince(dateRange.end)) / 3600.0
            let minDistance = min(distanceToStart, distanceToEnd)

            // Decay score based on distance (24 hours = 0.5, 48 hours = 0.25, etc.)
            return max(0.1, 1.0 / (1.0 + minDistance / 24.0))
        }
    }

    private func calculateTimeProximity(_ eventDate: Date, anchor: Date) -> Double {
        let hoursDiff = abs(eventDate.timeIntervalSince(anchor)) / 3600.0
        let tolerance = userPreferences.timeToleranceHours

        if hoursDiff <= tolerance / 4 {
            return 1.0
        } else if hoursDiff <= tolerance {
            return 1.0 - (hoursDiff / tolerance) * 0.5
        } else {
            return max(0.1, 0.5 - (hoursDiff - tolerance) / (tolerance * 2))
        }
    }

    private func getIntentSpecificWeights(_ intent: Intent) -> IntentWeights {
        switch intent {
        case .cancelEvent:
            return IntentWeights(title: 0.4, temporal: 0.3, contextual: 0.2, behavioral: 0.05, semantic: 0.05)
        case .updateEvent:
            return IntentWeights(title: 0.5, temporal: 0.2, contextual: 0.15, behavioral: 0.1, semantic: 0.05)
        case .rescheduleEvent:
            return IntentWeights(title: 0.4, temporal: 0.4, contextual: 0.1, behavioral: 0.05, semantic: 0.05)
        default:
            return IntentWeights(title: 0.4, temporal: 0.3, contextual: 0.15, behavioral: 0.1, semantic: 0.05)
        }
    }

    private func getImportantKeywords(for intent: Intent) -> Set<String> {
        switch intent {
        case .cancelEvent:
            return ["meeting", "appointment", "call", "event"]
        case .updateEvent:
            return ["meeting", "appointment", "call", "event", "title", "name"]
        case .rescheduleEvent:
            return ["meeting", "appointment", "call", "event", "time", "date"]
        default:
            return []
        }
    }

    private func getTemporalModifier(for intent: Intent, event: EventOccurrence, now: Date) -> Double {
        switch intent {
        case .cancelEvent:
            // Prefer future events for cancellation
            return event.startDate > now ? 1.0 : 0.3
        case .updateEvent, .rescheduleEvent:
            // Allow recent past events for updates
            return event.endDate > now.addingTimeInterval(-3600) ? 1.0 : 0.5
        default:
            return 1.0
        }
    }

    private func calculateRecencyModifier(event: EventOccurrence, intent: Intent, now: Date) -> Double {
        if !userPreferences.preferRecent { return 1.0 }

        let daysSinceCreated = abs(event.startDate.timeIntervalSince(now)) / 86400.0
        return max(0.5, 1.0 - daysSinceCreated * 0.02) // Small bonus for recent events
    }

    private func calculateDayPatternModifier(event: EventOccurrence, command: CommandContext) -> Double {
        // Could implement day-of-week pattern matching
        return 1.0
    }

    private func getStatusRelevance(event: EventOccurrence, intent: Intent) -> Double {
        switch intent {
        case .cancelEvent:
            return event.isCancelled ? 0.1 : 1.0 // Avoid already cancelled events
        default:
            return event.isCancelled ? 0.5 : 1.0
        }
    }

    private func calculateRecurrenceRelevance(event: EventOccurrence, command: CommandContext, intent: Intent) -> Double? {
        // Could analyze recurrence patterns vs command context
        return nil
    }

    private func calculateDurationRelevance(event: EventOccurrence, command: CommandContext) -> Double {
        // Could match expected duration patterns
        return 1.0
    }

    private func calculateLocationContextScore(event: EventOccurrence, command: CommandContext) -> Double {
        // Could match location/context information
        return 1.0
    }

    private func calculateCategoryMatch(event: EventOccurrence, command: CommandContext) -> Double {
        // Could implement category/type classification
        return 0.5
    }

    private func calculateLocaleRelevance(event: EventOccurrence, command: CommandContext) -> Double {
        // Could implement language/locale awareness
        return 1.0
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)

        var matrix = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)

        for i in 0...a.count {
            matrix[i][0] = i
        }

        for j in 0...b.count {
            matrix[0][j] = j
        }

        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    matrix[i][j] = min(
                        matrix[i-1][j] + 1,    // deletion
                        matrix[i][j-1] + 1,    // insertion
                        matrix[i-1][j-1] + 1   // substitution
                    )
                }
            }
        }

        return matrix[a.count][b.count]
    }
}
