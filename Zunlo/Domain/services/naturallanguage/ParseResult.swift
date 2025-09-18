//
//  ParseResult.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/16/25.
//

import SwiftUI
import GlowUI
import SmartParseKit

public struct ParseResult: Identifiable {
    public let id: UUID
    public let title: String
    public let intent: Intent
    public let context: TemporalContext
    public let metadataTokens: [MetadataToken]
    public let intentAmbiguity: IntentAmbiguity?

    public init(id: UUID, title: String, intent: Intent, context: TemporalContext, metadataTokens: [MetadataToken] = [], intentAmbiguity: IntentAmbiguity? = nil) {
        self.id = id
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

extension ParseResult {
    func createDisambiguationText() -> String {
        var message = "I found multiple ways to interpret your request".localized

        if !self.title.isEmpty {
            message += " for \"\(self.title)\"".localized
        }

        message += ". Please choose what you'd like to do:".localized

        return message
    }
    
    func label(calendar: Calendar) -> AttributedString {
        return labelForIntent(self.intent, confidence: 1.0, calendar: calendar)
    }

//    func labelForIntent(_ intent: Intent, confidence: Float, calendar: Calendar) -> String {
//        var label = ""
//
//        // Add intent action
//        label = intent.localizedDescription
//
//        // Add title if available
//        if !self.title.isEmpty {
//            label += ": \"\(self.title)\""
//        }
//
//        // Add temporal context if available
//        if self.context.finalDate != .distantPast {
//            let dateStr = self.context.finalDate.formattedDate(
//                dateFormat: .long,
//                calendar: calendar,
//                timeZone: calendar.timeZone
//            )
//            label += " on \(dateStr)".localized
//        }
//
//        // Add confidence indicator for ambiguous cases
//        if confidence < 1.0 {
//            let percentageConfidence = Int(confidence * 100)
//            label += " (\(percentageConfidence)%)"
//        }
//
//        return label
//    }
    
    func labelForIntent(_ intent: Intent, confidence: Float, calendar: Calendar) -> AttributedString {
        var attributedLabel = AttributedString()
        
        // Intent action - most prominent
        var intentText = AttributedString(intent.localizedDescription)
        intentText.font = .body.weight(.semibold)
        intentText.foregroundColor = UIColor(Color.theme.text)
        attributedLabel += intentText
        
        // Title in quotes with different styling
        if !self.title.isEmpty {
            // Colon separator
            var separator = AttributedString(": ")
            separator.foregroundColor = UIColor(Color.theme.secondaryText)
            attributedLabel += separator
            
            // Title in quotes
            var titleText = AttributedString("\"\(self.title)\"\n")
            titleText.font = .body.italic()
            titleText.foregroundColor = UIColor(Color.theme.text)
            attributedLabel += titleText
        }
        
        // Date with icon-like styling
        if self.context.finalDate != .distantPast {
            let dateStr = self.context.finalDate.formattedDate(
                dateFormat: .long,
                calendar: calendar,
                timeZone: calendar.timeZone
            )
                        
            var dateText = AttributedString(dateStr)
            dateText.font = .callout.weight(.medium)
            dateText.foregroundColor = UIColor(Color.theme.secondaryText)
            attributedLabel += dateText
        }
        
        if EnvConfig.shared.environment == .dev {
            // Confidence as a subtle badge
            if confidence < 1.0 {
                let percentageConfidence = Int(confidence * 100)
                var confidenceText = AttributedString(" (\(percentageConfidence)%)")
                confidenceText.font = .caption.weight(.medium)
                confidenceText.foregroundColor = .orange
                attributedLabel += confidenceText
            }
        }
        
        return attributedLabel
    }
}
