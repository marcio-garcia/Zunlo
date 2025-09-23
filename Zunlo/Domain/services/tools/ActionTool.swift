//
//  ActionTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - ActionTool Protocol

/// Protocol for individual action tools that perform specific operations
protocol ActionTool {
    /// Perform the tool's action with the given command context
    func perform(_ context: CommandContext) async -> ToolResult
}

// MARK: - Supporting Types

struct ToolResult: Equatable {
    let intent: Intent
    let action: ToolAction
    let needsDisambiguation: Bool
    let options: [ChatMessageActionAlternative]
    let message: String?
    let richText: AttributedString?

    init(intent: Intent,
                action: ToolAction = .none,
                needsDisambiguation: Bool = false,
                options: [ChatMessageActionAlternative] = [],
                message: String? = nil,
                richText: AttributedString? = nil
    ) {
        self.intent = intent
        self.action = action
        self.needsDisambiguation = needsDisambiguation
        self.options = options
        self.message = message
        self.richText = richText
    }
}

public enum ToolError: Error, LocalizedError {
    case parentNotFound
    case unsupportedEditMode(String)

    public var errorDescription: String? {
        switch self {
        case .parentNotFound: return "Occurrence does not have a base event".localized
        case .unsupportedEditMode(let operation): return "Unsupported edit mode for \(operation.lowercased())".localized
        }
    }
}

public enum ToolAction: Equatable {
    case createdTask(id: UUID)
    case createdEvent(id: UUID)
    case updatedTask(id: UUID)
    case updatedEvent(id: UUID)

    // Targeting / selection hints
    case targetTask(id: UUID)
    case targetEventSeries(id: UUID)
    case targetEventOccurrence(eventId: UUID, start: Date)
    case targetEventOverride(id: UUID)

    // Reschedule intents (explicit new timing + scope so the VM can apply if needed)
    case rescheduledTask(id: UUID, due: Date)
    case rescheduledEvent(eventId: UUID, start: Date, end: Date)

    case canceledTask(id: UUID)
    case canceledEvent(id: UUID)

    case plannedDay(range: Range<Date>, occurrences: [EventOccurrence])
    case plannedWeek(range: Range<Date>, occurrences: [EventOccurrence])
    case agenda(range: Range<Date>, occurrences: [EventOccurrence])
    case info(message: String)
    case none
}
