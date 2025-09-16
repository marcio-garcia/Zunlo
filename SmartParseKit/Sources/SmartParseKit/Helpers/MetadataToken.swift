//
//  MetadataToken.swift
//  SmartParseKit
//
//  Created by Claude on 9/13/25.
//

import Foundation

// MARK: - MetadataToken Types

public enum MetadataTokenKind: Equatable, Hashable {
    case tag(name: String, confidence: Float)
    case reminder(trigger: ReminderTriggerToken, confidence: Float)
    case priority(level: TaskPriority, confidence: Float)
    case location(name: String, confidence: Float)
    case notes(content: String, confidence: Float)
}

public enum ReminderTriggerToken: Equatable, Hashable {
    case timeOffset(TimeInterval) // e.g., 30 minutes before
    case absoluteTime(Date)       // e.g., at 9am
    case location(String)         // e.g., when arriving at "home"
}

public enum TaskPriority: String, CaseIterable, Equatable, Hashable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
}

public struct MetadataToken: Equatable, Hashable {
    public let range: NSRange
    public let text: String
    public let kind: MetadataTokenKind
    public let confidence: Float // Overall confidence for this token (0.0 to 1.0)

    public init(range: NSRange, text: String, kind: MetadataTokenKind, confidence: Float) {
        self.range = range
        self.text = text
        self.kind = kind
        self.confidence = min(1.0, max(0.0, confidence))
    }

    /// Extract the specific confidence from the kind
    public var kindConfidence: Float {
        switch kind {
        case .tag(_, let confidence),
             .reminder(_, let confidence),
             .priority(_, let confidence),
             .location(_, let confidence),
             .notes(_, let confidence):
            return confidence
        }
    }

    /// Returns true if this token represents ambiguous content that needs clarification
    public var isAmbiguous: Bool {
        return confidence < 0.6 || kindConfidence < 0.6
    }

    /// Priority for conflict resolution (higher = more important)
    public func tokenPriority() -> Int {
        switch kind {
        case .tag: return 80
        case .priority: return 75
        case .reminder: return 70
        case .location: return 60
        case .notes: return 50
        }
    }
}

// MARK: - MetadataExtraction Result

public struct MetadataExtractionResult {
    public let tokens: [MetadataToken]
    public let title: String
    public let confidence: Float
    public let conflicts: [MetadataConflict]
    public let intentAmbiguity: IntentAmbiguity?

    public init(tokens: [MetadataToken], title: String, confidence: Float, conflicts: [MetadataConflict] = [], intentAmbiguity: IntentAmbiguity? = nil) {
        self.tokens = tokens
        self.title = title
        self.confidence = confidence
        self.conflicts = conflicts
        self.intentAmbiguity = intentAmbiguity
    }

    /// Extract tokens of a specific kind
    public func tokens(of kind: MetadataTokenKind) -> [MetadataToken] {
        return tokens.filter { token in
            switch (token.kind, kind) {
            case (.tag, .tag): return true
            case (.reminder, .reminder): return true
            case (.priority, .priority): return true
            case (.location, .location): return true
            case (.notes, .notes): return true
            default: return false
            }
        }
    }

    /// Get all tag names with their confidence scores
    public var tags: [(name: String, confidence: Float)] {
        return tokens.compactMap { token in
            if case .tag(let name, let confidence) = token.kind {
                return (name, confidence)
            }
            return nil
        }
    }

    /// Get all reminders with their trigger and confidence scores
    public var reminders: [(trigger: ReminderTriggerToken, confidence: Float)] {
        return tokens.compactMap { token in
            if case .reminder(let trigger, let confidence) = token.kind {
                return (trigger, confidence)
            }
            return nil
        }
    }

    /// Get the highest confidence priority level
    public var priority: (level: TaskPriority, confidence: Float)? {
        let priorityTokens = tokens.compactMap { token -> (TaskPriority, Float)? in
            if case .priority(let level, let confidence) = token.kind {
                return (level, confidence)
            }
            return nil
        }
        return priorityTokens.max { $0.1 < $1.1 }.map { (level: $0.0, confidence: $0.1) }
    }

    /// Get the highest confidence location
    public var location: (name: String, confidence: Float)? {
        let locationTokens = tokens.compactMap { token -> (String, Float)? in
            if case .location(let name, let confidence) = token.kind {
                return (name, confidence)
            }
            return nil
        }
        return locationTokens.max { $0.1 < $1.1 }.map { (name: $0.0, confidence: $0.1) }
    }

    /// Get the highest confidence notes
    public var notes: (content: String, confidence: Float)? {
        let notesTokens = tokens.compactMap { token -> (String, Float)? in
            if case .notes(let content, let confidence) = token.kind {
                return (content, confidence)
            }
            return nil
        }
        return notesTokens.max { $0.1 < $1.1 }.map { (content: $0.0, confidence: $0.1) }
    }
}

public struct MetadataConflict: Equatable {
    public let description: String
    public let conflictingTokens: [MetadataToken]
    public let severity: ConflictSeverity

    public enum ConflictSeverity: Int, Comparable {
        case low = 1
        case medium = 2
        case high = 3

        public static func < (lhs: ConflictSeverity, rhs: ConflictSeverity) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    public init(description: String, conflictingTokens: [MetadataToken], severity: ConflictSeverity) {
        self.description = description
        self.conflictingTokens = conflictingTokens
        self.severity = severity
    }
}
