//
//  CommandContext.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/22/25.
//

import Foundation
import SmartParseKit

/// Centralized context for command processing and tool execution
/// Contains all information needed throughout the chat processing flow
struct CommandContext: Identifiable {
    let id: UUID

    // Original parsing information
    let originalText: String
    let title: String
    let intent: Intent
    let temporalContext: TemporalContext
    let metadataTokens: [MetadataToken]

    // Disambiguation state
    let intentAmbiguity: IntentAmbiguity?
    let selectedEntityId: UUID?
    let editEventMode: AddEditEventViewMode?

    // Processing metadata
    let createdAt: Date
    let isResolved: Bool

    init(
        id: UUID = UUID(),
        originalText: String,
        title: String,
        intent: Intent,
        temporalContext: TemporalContext,
        metadataTokens: [MetadataToken] = [],
        intentAmbiguity: IntentAmbiguity? = nil,
        selectedEntityId: UUID? = nil,
        editEventMode: AddEditEventViewMode? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.originalText = originalText
        self.title = title
        self.intent = intent
        self.temporalContext = temporalContext
        self.metadataTokens = metadataTokens
        self.intentAmbiguity = intentAmbiguity
        self.selectedEntityId = selectedEntityId
        self.editEventMode = editEventMode
        self.createdAt = createdAt
        self.isResolved = intentAmbiguity == nil && selectedEntityId != nil
    }

    /// Create CommandContext from ParseResult
    public static func from(parseResult: ParseResult) -> CommandContext {
        return CommandContext(
            id: UUID(), // New ID for context
            originalText: parseResult.originalText,
            title: parseResult.title,
            intent: parseResult.intent,
            temporalContext: parseResult.context,
            metadataTokens: parseResult.metadataTokens,
            intentAmbiguity: parseResult.intentAmbiguity
        )
    }

    /// Create a resolved context with selected intent
    public func withSelectedIntent(_ selectedIntent: Intent) -> CommandContext {
        return CommandContext(
            id: UUID(),
            originalText: originalText,
            title: title,
            intent: selectedIntent,
            temporalContext: temporalContext,
            metadataTokens: metadataTokens,
            intentAmbiguity: nil, // Clear ambiguity
            selectedEntityId: selectedEntityId,
            editEventMode: editEventMode,
            createdAt: createdAt
        )
    }

    /// Create a resolved context with selected entity
    public func withSelectedEntity(_ entityId: UUID, editMode: AddEditEventViewMode? = nil) -> CommandContext {
        return CommandContext(
            id: UUID(),
            originalText: originalText,
            title: title,
            intent: intent,
            temporalContext: temporalContext,
            metadataTokens: metadataTokens,
            intentAmbiguity: nil, // Clear ambiguity
            selectedEntityId: entityId,
            editEventMode: editMode ?? editEventMode,
            createdAt: createdAt
        )
    }
}

// MARK: - Convenience accessors

extension CommandContext {
    /// Check if this context has ambiguous intent
    public var hasIntentAmbiguity: Bool {
        return intentAmbiguity?.isAmbiguous == true
    }

    /// Check if this context needs entity selection
    public var needsEntitySelection: Bool {
        return !hasIntentAmbiguity && selectedEntityId == nil
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
