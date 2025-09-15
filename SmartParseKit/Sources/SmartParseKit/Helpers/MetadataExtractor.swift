//
//  MetadataExtractor.swift
//  SmartParseKit
//
//  Created by Claude on 9/13/25.
//

import Foundation

public struct MetadataExtractor {
    public init() {}

    /// Extracts metadata tokens and clean title from user input.
    /// - Parameters:
    ///   - text: Full user input.
    ///   - temporalRanges: Array of ranges occupied by temporal tokens.
    ///   - pack: DateLanguagePack for language-specific patterns.
    /// - Returns: MetadataExtractionResult with tokens, clean title, and confidence info.
    public func extractMetadata(
        from text: String,
        temporalRanges: [Range<String.Index>],
        pack: DateLanguagePack
    ) -> MetadataExtractionResult {

        var metadataTokens: [MetadataToken] = []
        var allUsedRanges: [Range<String.Index>] = temporalRanges
        var conflicts: [MetadataConflict] = []

        // Extract each type of metadata token
        let tagTokens = extractTagTokens(from: text, excludingRanges: temporalRanges, pack: pack)
        let reminderTokens = extractReminderTokens(from: text, excludingRanges: temporalRanges, pack: pack)
        let priorityTokens = extractPriorityTokens(from: text, excludingRanges: temporalRanges, pack: pack)
        let locationTokens = extractLocationTokens(from: text, excludingRanges: temporalRanges, pack: pack)
        let notesTokens = extractNotesTokens(from: text, excludingRanges: temporalRanges, pack: pack)

        metadataTokens.append(contentsOf: tagTokens)
        metadataTokens.append(contentsOf: reminderTokens)
        metadataTokens.append(contentsOf: priorityTokens)
        metadataTokens.append(contentsOf: locationTokens)
        metadataTokens.append(contentsOf: notesTokens)

        // Detect conflicts and adjust confidence
        conflicts = detectConflicts(in: metadataTokens)
        metadataTokens = adjustConfidenceForConflicts(metadataTokens, conflicts: conflicts)

        // Add metadata ranges to exclusion list for title extraction
        for token in metadataTokens {
            if let range = Range(token.range, in: text) {
                allUsedRanges.append(range)
            }
        }

        // Extract clean title by removing all used ranges
        let cleanTitle = extractCleanTitle(
            from: text,
            excludingRanges: allUsedRanges,
            pack: pack
        )

        // Calculate overall confidence
        let overallConfidence = calculateOverallConfidence(
            tokens: metadataTokens,
            conflicts: conflicts,
            titleLength: cleanTitle.count
        )

        return MetadataExtractionResult(
            tokens: metadataTokens,
            title: cleanTitle,
            confidence: overallConfidence,
            conflicts: conflicts
        )
    }

    // MARK: - Helper Methods

    /// Checks if an NSRange overlaps with any of the excluded ranges
    private func overlapsWithExcludedRanges(_ nsRange: NSRange, in text: String, excludingRanges: [Range<String.Index>]) -> Bool {
        guard let stringRange = Range(nsRange, in: text) else { return false }

        return excludingRanges.contains { excludedRange in
            stringRange.overlaps(excludedRange)
        }
    }

    // MARK: - Token Extraction Methods

    private func extractTagTokens(from text: String, excludingRanges: [Range<String.Index>], pack: DateLanguagePack) -> [MetadataToken] {
        guard let tagRegex = pack.tagPatternRegex() else { return [] }
        var tokens: [MetadataToken] = []

        // Check for command words first using existing intent detection
        let hasCommandWord = hasCommandWord(in: text, pack: pack)

        let nsText = text as NSString
        tagRegex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
            guard let match = match else { return }

            // Skip matches that overlap with temporal tokens
            if overlapsWithExcludedRanges(match.range, in: text, excludingRanges: excludingRanges) {
                return
            }

            for groupIndex in 1...match.numberOfRanges - 1 {
                let range = match.range(at: groupIndex)
                if range.location != NSNotFound && range.length > 0 {
                    let tagText = nsText.substring(with: range)
                    let tagNames = tagText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

                    for tagName in tagNames {
                        // Clean up special characters from tag names (@ and #)
                        let cleanedTagName = tagName.replacingOccurrences(of: "^[@#]+", with: "", options: .regularExpression)

                        if !cleanedTagName.isEmpty && cleanedTagName.count >= 2 && cleanedTagName.count <= 50 {
                            var confidence = calculateTagConfidence(cleanedTagName, fullMatch: nsText.substring(with: match.range))

                            // Boost confidence if command word is present
                            if hasCommandWord {
                                confidence += 0.2
                            }

                            confidence = min(1.0, max(0.1, confidence))
                            let token = MetadataToken(
                                range: match.range,
                                text: nsText.substring(with: match.range),
                                kind: .tag(name: String(cleanedTagName), confidence: confidence),
                                confidence: confidence
                            )
                            tokens.append(token)
                        }
                    }
                    break // Only process the first matching group
                }
            }
        }

        return tokens
    }

    private func hasCommandWord(in text: String, pack: DateLanguagePack) -> Bool {
        // Check for create/add commands using existing intent detection
        let createRegex = pack.intentCreateRegex()
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        return createRegex.firstMatch(in: text, options: [], range: range) != nil
    }

    private func extractReminderTokens(from text: String, excludingRanges: [Range<String.Index>], pack: DateLanguagePack) -> [MetadataToken] {
        guard let regex = pack.reminderPatternRegex() else { return [] }
        var tokens: [MetadataToken] = []

        let nsText = text as NSString
        regex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
            guard let match = match else { return }

            // Skip matches that overlap with temporal tokens
            if overlapsWithExcludedRanges(match.range, in: text, excludingRanges: excludingRanges) {
                return
            }

            let fullMatchText = nsText.substring(with: match.range)
            var trigger: ReminderTriggerToken?
            var confidence: Float = 0.5

            // Try to extract time offset (groups 1, 2 or 4, 5)
            if let offset = pack.extractReminderOffset(fullMatchText) {
                trigger = .timeOffset(offset)
                confidence = 0.8
            }
            // Try to extract absolute time (group 3)
            else if match.range(at: 3).location != NSNotFound {
                let timeRange = match.range(at: 3)
                let timeText = nsText.substring(with: timeRange)
                if let absoluteTime = parseAbsoluteTime(timeText) {
                    trigger = .absoluteTime(absoluteTime)
                    confidence = 0.7
                }
            }

            if let reminderTrigger = trigger {
                let token = MetadataToken(
                    range: match.range,
                    text: fullMatchText,
                    kind: .reminder(trigger: reminderTrigger, confidence: confidence),
                    confidence: confidence
                )
                tokens.append(token)
            }
        }

        return tokens
    }

    private func extractPriorityTokens(from text: String, excludingRanges: [Range<String.Index>], pack: DateLanguagePack) -> [MetadataToken] {
        guard let regex = pack.priorityPatternRegex() else { return [] }
        var tokens: [MetadataToken] = []

        let nsText = text as NSString
        regex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
            guard let match = match else { return }

            // Skip matches that overlap with temporal tokens
            if overlapsWithExcludedRanges(match.range, in: text, excludingRanges: excludingRanges) {
                return
            }

            for groupIndex in 1...match.numberOfRanges - 1 {
                let range = match.range(at: groupIndex)
                if range.location != NSNotFound && range.length > 0 {
                    let priorityText = nsText.substring(with: range)
                    if let priority = pack.classifyPriority(priorityText) {
                        let confidence = calculatePriorityConfidence(priorityText, fullMatch: nsText.substring(with: match.range))
                        let token = MetadataToken(
                            range: match.range,
                            text: nsText.substring(with: match.range),
                            kind: .priority(level: priority, confidence: confidence),
                            confidence: confidence
                        )
                        tokens.append(token)
                        break
                    }
                }
            }
        }

        return tokens
    }

    private func extractLocationTokens(from text: String, excludingRanges: [Range<String.Index>], pack: DateLanguagePack) -> [MetadataToken] {
        guard let regex = pack.locationPatternRegex() else { return [] }
        var tokens: [MetadataToken] = []

        let nsText = text as NSString
        regex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
            guard let match = match else { return }

            // Skip matches that overlap with temporal tokens
            if overlapsWithExcludedRanges(match.range, in: text, excludingRanges: excludingRanges) {
                return
            }

            for groupIndex in 1...match.numberOfRanges - 1 {
                let range = match.range(at: groupIndex)
                if range.location != NSNotFound && range.length > 0 {
                    let locationText = nsText.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
                    if locationText.count >= 2 && locationText.count <= 50 {
                        let confidence = calculateLocationConfidence(locationText, fullMatch: nsText.substring(with: match.range))
                        let token = MetadataToken(
                            range: match.range,
                            text: nsText.substring(with: match.range),
                            kind: .location(name: locationText, confidence: confidence),
                            confidence: confidence
                        )
                        tokens.append(token)
                        break
                    }
                }
            }
        }

        return tokens
    }

    private func extractNotesTokens(from text: String, excludingRanges: [Range<String.Index>], pack: DateLanguagePack) -> [MetadataToken] {
        guard let regex = pack.notesPatternRegex() else { return [] }
        var tokens: [MetadataToken] = []

        let nsText = text as NSString
        regex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
            guard let match = match else { return }

            // Skip matches that overlap with temporal tokens
            if overlapsWithExcludedRanges(match.range, in: text, excludingRanges: excludingRanges) {
                return
            }

            if match.range(at: 1).location != NSNotFound {
                let notesRange = match.range(at: 1)
                let notesText = nsText.substring(with: notesRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if notesText.count >= 3 && notesText.count <= 200 {
                    let confidence = calculateNotesConfidence(notesText, fullMatch: nsText.substring(with: match.range))
                    let token = MetadataToken(
                        range: match.range,
                        text: nsText.substring(with: match.range),
                        kind: .notes(content: notesText, confidence: confidence),
                        confidence: confidence
                    )
                    tokens.append(token)
                }
            }
        }

        return tokens
    }

    // MARK: - Helper Methods

    private func extractCleanTitle(
        from text: String,
        excludingRanges: [Range<String.Index>],
        pack: DateLanguagePack
    ) -> String {
        // Merge overlapping ranges
        let merged = mergeRanges(excludingRanges, in: text)

        // Build result by keeping everything outside merged ranges
        var pieces: [Substring] = []
        var cursor = text.startIndex

        for range in merged {
            if cursor < range.lowerBound {
                pieces.append(text[cursor..<range.lowerBound])
            }
            if cursor < range.upperBound {
                cursor = range.upperBound
            }
        }
        if cursor < text.endIndex {
            pieces.append(text[cursor..<text.endIndex])
        }

        var result = pieces.reduce(into: String(), { $0.append(contentsOf: $1) })

        // Strip language-specific connector tokens and command prefixes
        let tokens = pack.connectorTokens
        for token in tokens {
            result = result.replacingOccurrences(
                of: "\\b\(NSRegularExpression.escapedPattern(for: token))\\b",
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        let regexList = pack.commandPrefixRegex()
        for regex in regexList {
            while let match = regex.firstMatch(in: result, options: [], range: NSRange(result.startIndex..., in: result)),
                  match.range.location == 0, match.range.length > 0,
                  let range = Range(match.range, in: result) {
                result.removeSubrange(range)
            }
        }

        // Strip task and event keywords that might appear at the end
        let taskKeywordRegex = pack.taskKeywordsRegex()
        let eventKeywordRegex = pack.eventKeywordsRegex()

        // Remove task keywords from anywhere in the string
        let taskMatches = taskKeywordRegex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
        for match in taskMatches.reversed() { // reverse to avoid index shifting
            if let range = Range(match.range, in: result) {
                result.removeSubrange(range)
            }
        }

        // Remove event keywords from anywhere in the string
        let eventMatches = eventKeywordRegex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
        for match in eventMatches.reversed() { // reverse to avoid index shifting
            if let range = Range(match.range, in: result) {
                result.removeSubrange(range)
            }
        }

        // Strip common temporal keywords that might not be captured as temporal tokens
        if let relativeDayRegex = pack.relativeDayRegex() {
            result = relativeDayRegex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: " ")
        }

        if let partOfDayRegex = pack.partOfDayRegex() {
            result = partOfDayRegex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: " ")
        }

        // Normalize whitespace & punctuation
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"^[\s,;:.-]+"#, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: #"[\s,;:.-]+$"#, with: "", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mergeRanges(_ ranges: [Range<String.Index>], in text: String) -> [Range<String.Index>] {
        guard !ranges.isEmpty else { return [] }
        let sorted = ranges.sorted { $0.lowerBound < $1.lowerBound }

        var merged: [Range<String.Index>] = []
        var current = sorted[0]

        for range in sorted.dropFirst() {
            if range.lowerBound <= current.upperBound { // overlap or adjacency
                if range.upperBound > current.upperBound {
                    current = current.lowerBound..<range.upperBound
                }
            } else {
                merged.append(current)
                current = range
            }
        }
        merged.append(current)
        return merged
    }

    // MARK: - Confidence Calculation

    private func calculateTagConfidence(_ tagName: String, fullMatch: String) -> Float {
        var confidence: Float = 0.7 // Base confidence

        // Higher confidence for explicit patterns like "tag work"
        if fullMatch.lowercased().contains("tag") || fullMatch.lowercased().contains("etiqueta") {
            confidence += 0.2
        }

        // Lower confidence for very short or very long tags
        if tagName.count < 3 { confidence -= 0.3 }
        if tagName.count > 20 { confidence -= 0.2 }

        // Higher confidence for common tag patterns
        if tagName.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil {
            confidence += 0.1
        }

        return min(1.0, max(0.1, confidence))
    }

    private func calculatePriorityConfidence(_ priorityText: String, fullMatch: String) -> Float {
        var confidence: Float = 0.8 // Base confidence for priority

        // Higher confidence for explicit priority patterns
        if fullMatch.lowercased().contains("priority") || fullMatch.lowercased().contains("prioridade") {
            confidence += 0.1
        }

        // Higher confidence for strong priority words
        let text = priorityText.lowercased()
        if text.contains("urgent") || text.contains("critical") || text.contains("urgente") || text.contains("crítica") {
            confidence += 0.1
        }

        return min(1.0, max(0.3, confidence))
    }

    private func calculateLocationConfidence(_ locationText: String, fullMatch: String) -> Float {
        var confidence: Float = 0.6 // Base confidence for location

        // Higher confidence for explicit location patterns
        if fullMatch.lowercased().contains("location") || fullMatch.lowercased().contains("local") ||
           fullMatch.lowercased().contains("at ") || fullMatch.lowercased().contains(" em ") {
            confidence += 0.2
        }

        // Lower confidence for very generic words
        let genericWords = ["place", "here", "there", "location", "local", "lugar"]
        if genericWords.contains(where: { locationText.lowercased().contains($0) }) {
            confidence -= 0.2
        }

        return min(1.0, max(0.2, confidence))
    }

    private func calculateNotesConfidence(_ notesText: String, fullMatch: String) -> Float {
        var confidence: Float = 0.8 // Base confidence for notes

        // Higher confidence for explicit note patterns
        if fullMatch.lowercased().contains("note") || fullMatch.lowercased().contains("comment") ||
           fullMatch.lowercased().contains("nota") || fullMatch.lowercased().contains("comentario") {
            confidence += 0.1
        }

        // Lower confidence for very short notes
        if notesText.count < 10 { confidence -= 0.2 }

        return min(1.0, max(0.3, confidence))
    }

    private func calculateTitleConfidence(_ title: String) -> Float {
        var confidence: Float = 0.7 // Base confidence for title

        // Higher confidence for reasonable length titles
        if title.count >= 5 && title.count <= 50 {
            confidence += 0.2
        }

        // Lower confidence for very short or long titles
        if title.count < 3 { confidence -= 0.4 }
        if title.count > 100 { confidence -= 0.3 }

        return min(1.0, max(0.1, confidence))
    }

    private func calculateOverallConfidence(tokens: [MetadataToken], conflicts: [MetadataConflict], titleLength: Int) -> Float {
        guard !tokens.isEmpty else { return 0.0 }

        let averageTokenConfidence = tokens.map { $0.confidence }.reduce(0, +) / Float(tokens.count)
        var overallConfidence = averageTokenConfidence

        // Reduce confidence based on conflicts
        let conflictPenalty = conflicts.reduce(0) { (sum, conflict) -> Float in
            switch conflict.severity {
            case .low: return sum + 0.05
            case .medium: return sum + 0.15
            case .high: return sum + 0.30
            }
        }
        overallConfidence -= conflictPenalty

        // Boost confidence if we have a good title
        if titleLength >= 3 && titleLength <= 50 {
            overallConfidence += 0.1
        }

        return min(1.0, max(0.0, overallConfidence))
    }

    // MARK: - Conflict Detection

    private func detectConflicts(in tokens: [MetadataToken]) -> [MetadataConflict] {
        var conflicts: [MetadataConflict] = []

        // Detect multiple priority tokens
        let priorityTokens = tokens.filter {
            if case .priority = $0.kind { return true }
            return false
        }
        if priorityTokens.count > 1 {
            conflicts.append(MetadataConflict(
                description: "Multiple priority levels detected",
                conflictingTokens: priorityTokens,
                severity: .medium
            ))
        }

        // Detect overlapping ranges (should be rare but possible)
        for i in 0..<tokens.count {
            for j in (i+1)..<tokens.count {
                let range1 = tokens[i].range
                let range2 = tokens[j].range
                if NSLocationInRange(range1.location, range2) || NSLocationInRange(range2.location, range1) {
                    conflicts.append(MetadataConflict(
                        description: "Overlapping token ranges detected",
                        conflictingTokens: [tokens[i], tokens[j]],
                        severity: .high
                    ))
                }
            }
        }

        return conflicts
    }

    private func adjustConfidenceForConflicts(_ tokens: [MetadataToken], conflicts: [MetadataConflict]) -> [MetadataToken] {
        var adjustedTokens = tokens

        for conflict in conflicts {
            for (index, token) in adjustedTokens.enumerated() {
                if conflict.conflictingTokens.contains(token) {
                    let penalty: Float = switch conflict.severity {
                    case .low: 0.1
                    case .medium: 0.2
                    case .high: 0.4
                    }
                    let newConfidence = max(0.1, token.confidence - penalty)
                    let newKind: MetadataTokenKind = switch token.kind {
                    case .title(let title, _): .title(title: title, confidence: newConfidence)
                    case .tag(let name, _): .tag(name: name, confidence: newConfidence)
                    case .reminder(let trigger, _): .reminder(trigger: trigger, confidence: newConfidence)
                    case .priority(let level, _): .priority(level: level, confidence: newConfidence)
                    case .location(let name, _): .location(name: name, confidence: newConfidence)
                    case .notes(let content, _): .notes(content: content, confidence: newConfidence)
                    }
                    adjustedTokens[index] = MetadataToken(
                        range: token.range,
                        text: token.text,
                        kind: newKind,
                        confidence: newConfidence
                    )
                }
            }
        }

        return adjustedTokens
    }

    // MARK: - Time Parsing Helper

    private func parseAbsoluteTime(_ timeText: String) -> Date? {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        // Try different time formats
        let formats = ["H:mm", "h:mm a", "HH:mm", "h a"]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: timeText) {
                return date
            }
        }

        return nil
    }
}
