//
//  RescheduleEventTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Reschedule Event Tool

/// Tool for rescheduling events with enhanced candidate selection
final class RescheduleEventTool: BaseEventTool, ActionTool {

    private let referenceDate: Date

    init(events: EventStore, referenceDate: Date, calendar: Calendar = .appDefault) {
        self.referenceDate = referenceDate
        super.init(events: events, calendar: calendar)
    }

    // MARK: - ActionTool Conformance

    func perform(_ command: CommandContext) async -> ToolResult {
        do {

            // Check if user selected a specific entity occurrence
            if let selectedOccurrence = command.selectedEventOccurrence {
                return await self.performEventReschedule(selectedOccurrence, command: command)
            }

            // 1. Fetch all events
            let allEvents = try await events.fetchOccurrences()
            let searchWindow = DateInterval(start: referenceDate.startOfDay(calendar: calendar),
                                            end: command.temporalContext.finalDate.startOfNextDay(calendar: calendar))
            let allOccurrences = try EventOccurrenceService.generate(rawOccurrences: allEvents, in: searchWindow.toDateRange())

            // 2. Pre-filter events for reschedule context
            let relevantEvents = filterEventsByDate(
                allOccurrences,
                context: command,
                excludeCancelled: true,
                allowPastEvents: true,
                pastEventToleranceHours: 1.0,
                referenceDate: referenceDate,
                searchWindow: searchWindow
            )

            // 3. Use enhanced picker for better candidate selection
            let selection = eventPicker.selectEventCandidate(
                from: relevantEvents,
                for: command,
                intent: .rescheduleEvent,
                referenceDate: referenceDate,
                searchWindow: searchWindow
            )

            // 4. Handle selection based on confidence
            return await handleEventSelection(selection, context: command, intent: .rescheduleEvent) { event in
                await self.performEventReschedule(event, command: command)
            }

        } catch {
            return ToolResult(
                intent: command.intent,
                action: .info(message: "Error"),
                needsDisambiguation: false,
                options: [],
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Event Rescheduling

    private func performEventReschedule(
        _ event: EventOccurrence,
        command: CommandContext
    ) async -> ToolResult {

        do {
            // Extract new timing from command
            guard let newTiming = extractNewTiming(from: command, originalEvent: event) else {
                return ToolResult(
                    intent: command.intent,
                    action: .info(message: "More info"),
                    needsDisambiguation: false,
                    options: [],
                    message: "Please specify the new date or time for the event.".localized
                )
            }

            if event.isRecurring {
                // For recurring events, always ask for scope clarification
                let parent = try await fetchParentOccurrence(for: event)
                
                if let editMode = command.editEventMode {
                    let duration = event.endDate.timeIntervalSince(event.startDate)
                    let newEndDate = newTiming.addingTimeInterval(duration)
                    let editInput = buildEditInput(from: event, newStart: newTiming, newEnd: newEndDate)

                    switch editMode {
                    case .add: break                        
                    case .editAll(let event, let recurrenceRule):
                        try await events.editAll(event: event, with: editInput, oldRule: recurrenceRule)
                    case .editSingleOccurrence(let parentEvent, _, let occurrence):
                        try await events.editSingleOccurrence(parent: parentEvent, occurrence: occurrence, with: editInput)
                    case .editOverride(let override):
                        try await events.editOverride(override, with: editInput)
                    case .editFuture(let parentEvent, _, let startingFrom):
                        try await events.editFuture(parent: parentEvent, startingFrom: startingFrom, with: editInput)
                    }
                    
                    return ToolResult(
                        intent: command.intent,
                        action: .rescheduledEvent(eventId: event.id, start: newTiming, end: newEndDate),
                        needsDisambiguation: false,
                        options: [],
                        message: String(
                            format: "Rescheduled '%@' to %@ %@.".localized,
                            event.title,
                            formatDay(newTiming),
                            formatTimeRange(newTiming, newEndDate)
                        ))
                }
                
                let opts = try buildScopeOptions(
                    for: event,
                    parent: parent,
                    parseResultId: command.id,
                    intent: command.intent,
                    actionLabels: (
                        single: "Reschedule only this occurrence".localized,
                        future: "Reschedule this and future occurrences".localized,
                        all: "Reschedule all occurrences".localized
                    )
                )

                return ToolResult(
                    intent: command.intent,
                    action: .targetEventOccurrence(eventId: event.id, start: event.startDate),
                    needsDisambiguation: true,
                    options: opts,
                    message: "Do you want to reschedule just this occurrence or the entire series?".localized
                )
            } else {
                // Single event - reschedule directly
                let duration = event.endDate.timeIntervalSince(event.startDate)
                let newEndDate = newTiming.addingTimeInterval(duration)

                let editInput = buildEditInput(from: event, newStart: newTiming, newEnd: newEndDate)

                try await events.editAll(
                    event: event,
                    with: editInput,
                    oldRule: nil
                )

                return ToolResult(
                    intent: command.intent,
                    action: .rescheduledEvent(eventId: event.id, start: newTiming, end: newEndDate),
                    needsDisambiguation: false,
                    options: [],
                    message: String(
                        format: "Rescheduled '%@' to %@ %@.".localized,
                        event.title,
                        formatDay(newTiming),
                        formatTimeRange(newTiming, newEndDate)
                    )
                )
            }
        } catch {
            return ToolResult(
                intent: command.intent,
                action: .info(message: "More info"),
                needsDisambiguation: false,
                options: [],
                message: "Failed to reschedule event: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Timing Extraction

    private func extractNewTiming(from command: CommandContext, originalEvent: EventOccurrence) -> Date? {
        let context = command.temporalContext

        // If there's a specific new date in the context, use it
//        if let dateRange = context.dateRange {
//            return dateRange.start
//        }

        // Use the final date from context
        if context.finalDate != originalEvent.startDate {
            return context.finalDate
        }

        return nil
    }
}
