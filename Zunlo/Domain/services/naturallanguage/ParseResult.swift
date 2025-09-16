//
//  ParseResult.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/16/25.
//

import SmartParseKit

public struct ParseResult {
    public let title: String
    public let intent: Intent
    public let context: TemporalContext
    public let metadataTokens: [MetadataToken]
    public let intentAmbiguity: IntentAmbiguity?

    public init(title: String, intent: Intent, context: TemporalContext, metadataTokens: [MetadataToken] = [], intentAmbiguity: IntentAmbiguity? = nil) {
        self.title = title
        self.intent = intent
        self.context = context
        self.metadataTokens = metadataTokens
        self.intentAmbiguity = intentAmbiguity
    }

    /// Check if this parse result has ambiguous intent
    public var isAmbiguous: Bool {
        return intentAmbiguity?.isAmbiguous == true
    }

    /// Get alternative intents if ambiguous
    public var alternatives: [IntentPrediction] {
        return intentAmbiguity?.alternatives ?? []
    }

    /// Extract tags with their confidence scores
    public var tags: [(name: String, confidence: Float)] {
        return metadataTokens.compactMap { token in
            if case .tag(let name, let confidence) = token.kind {
                return (name: name, confidence: confidence)
            }
            return nil
        }
    }

    /// Get the highest confidence priority level
    public var priority: (level: TaskPriority, confidence: Float)? {
        let priorityTokens = metadataTokens.compactMap { token -> (TaskPriority, Float)? in
            if case .priority(let level, let confidence) = token.kind {
                return (level, confidence)
            }
            return nil
        }
        return priorityTokens.max { $0.1 < $1.1 }.map { (level: $0.0, confidence: $0.1) }
    }

    /// Get all reminder triggers
    public var reminders: [(trigger: SmartParseKit.ReminderTriggerToken, confidence: Float)] {
        let tokens = metadataTokens.compactMap { token in
            if case .reminder(let trigger, let confidence) = token.kind {
                return (trigger: trigger, confidence: confidence)
            }
            return nil
        }
        return tokens
    }

    /// Get location information
    public var location: (name: String, confidence: Float)? {
        let locationToken = metadataTokens.first { token in
            if case .location = token.kind { return true }
            return false
        }
        if let token = locationToken, case .location(let name, let confidence) = token.kind {
            return (name: name, confidence: confidence)
        }
        return nil
    }

    /// Get notes content
    public var notes: (content: String, confidence: Float)? {
        let notesToken = metadataTokens.first { token in
            if case .notes = token.kind { return true }
            return false
        }
        if let token = notesToken, case .notes(let content, let confidence) = token.kind {
            return (content: content, confidence: confidence)
        }
        return nil
    }
}
