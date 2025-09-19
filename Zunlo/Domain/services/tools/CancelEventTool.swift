//
//  CancelEventTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Cancel Event Tool

/// Tool for canceling events with enhanced candidate selection
final class CancelEventTool: BaseEventTool, ActionTool {

    private let referenceDate: Date
    
    init(events: EventStore, referenceDate: Date, calendar: Calendar = .appDefault) {
        self.referenceDate = referenceDate
        super.init(events: events, calendar: calendar)
    }

    // MARK: - ActionTool Conformance

    func perform(_ command: ParseResult) async -> ToolResult {
        do {
            // 1. Fetch all events
            let allEvents = try await events.fetchOccurrences()

            // 2. Pre-filter events for cancellation context
            let relevantEvents = filterEventsForOperation(
                allEvents,
                command: command,
                excludeCancelled: true,
                allowPastEvents: true,
                pastEventToleranceHours: 1.0,
                referenceDate: referenceDate
            )

            // 3. Use enhanced picker for better candidate selection
            let selection = eventPicker.selectEventCandidate(
                from: relevantEvents,
                for: command,
                intent: .cancelEvent,
                referenceDate: referenceDate
            )

            // 4. Handle selection based on confidence
            return await handleEventSelection(selection, command: command, intent: .cancelEvent) { event in
                await self.performEventCancellation(event, command: command)
            }

        } catch {
            return ToolResult(
                intent: command.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Event Cancellation

    private func performEventCancellation(
        _ event: EventOccurrence,
        command: ParseResult
    ) async -> ToolResult {

        do {
            if event.isRecurring {
                // For recurring events, always ask for scope clarification
                let parent = try await fetchParentOccurrence(for: event)
                let opts = try buildScopeOptions(
                    for: event,
                    parent: parent,
                    parseResultId: command.id,
                    intent: command.intent,
                    actionLabels: (
                        single: "Cancel only this occurrence".localized,
                        future: "Cancel this and future occurrences".localized,
                        all: "Cancel all occurrences".localized
                    )
                )

                return ToolResult(
                    intent: command.intent,
                    action: .targetEventOccurrence(eventId: event.id, start: event.startDate),
                    needsDisambiguation: true,
                    options: opts,
                    message: "Do you want to cancel just this occurrence or the entire series?".localized
                )
            } else {
                // Single event - cancel directly
                try await events.delete(id: event.id)
                return ToolResult(
                    intent: command.intent,
                    action: .canceledEvent(id: event.id),
                    needsDisambiguation: false,
                    options: [],
                    message: String(format: "Cancelled '%@'.".localized, event.title)
                )
            }
        } catch {
            return ToolResult(
                intent: command.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: "Failed to cancel event: \(error.localizedDescription)"
            )
        }
    }
}
