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
/// 1) Process input text
/// 2) If intent is ambiguous, ask for clarification
/// 3) Correct intent is selected
/// 4) Process with selected intent
/// 5) If found more than one event candidate, ask for clarification
/// 6) Specific event is selected
/// 7) Process rescheduling on the selected event
/// 8) If the event is recurrent, ask if the update is for all, single or this and future
/// 9) Edit mode is selected
/// 10) Process rescheduling on selected occurrence with selected mode
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
            return await handleRecurringEventReschedule(event, newTiming: newTiming, command: command)
        } else {
            return await handleSingleEventReschedule(event, newTiming: newTiming, command: command)
        }
    }

    // MARK: - Timing Extraction

    private func extractNewTiming(from command: CommandContext, originalEvent: EventOccurrence) -> Date? {
        let context = command.temporalContext

        // Use the final date from context
        if context.finalDate != originalEvent.startDate {
            return context.finalDate
        }

        return nil
    }
    
    private func calculateNewEndDate(from event: EventOccurrence, newStart: Date) -> Date {
        let duration = event.endDate.timeIntervalSince(event.startDate)
        return newStart.addingTimeInterval(duration)
    }

    // MARK: - Recurring Event Handling

    private func handleRecurringEventReschedule(
        _ event: EventOccurrence,
        newTiming: Date,
        command: CommandContext
    ) async -> ToolResult {
        return await handleRecurringEventOperation(
            event,
            command: command,
            actionLabels: (
                single: "Reschedule only this occurrence".localized,
                future: "Reschedule this and future occurrences".localized,
                all: "Reschedule all occurrences".localized
            ),
            disambiguationMessage: "Do you want to reschedule just this occurrence or the entire series?".localized,
            operationName: "Reschedule",
            editInputBuilder: {
                let newEndDate = self.calculateNewEndDate(from: event, newStart: newTiming)
                return self.buildEditInput(from: event, newStart: newTiming, newEnd: newEndDate)
            },
            successResultBuilder: {
                let newEndDate = self.calculateNewEndDate(from: event, newStart: newTiming)
                return self.createSuccessResult(for: event, newTiming: newTiming, newEndDate: newEndDate, command: command)
            }
        )
    }

    // MARK: - Single Event Handling

    private func handleSingleEventReschedule(
        _ event: EventOccurrence,
        newTiming: Date,
        command: CommandContext
    ) async -> ToolResult {
        return await handleSingleEventOperation(
            event,
            command: command,
            operationName: "Reschedule",
            editInputBuilder: {
                let newEndDate = self.calculateNewEndDate(from: event, newStart: newTiming)
                return self.buildEditInput(from: event, newStart: newTiming, newEnd: newEndDate)
            },
            successResultBuilder: {
                let newEndDate = self.calculateNewEndDate(from: event, newStart: newTiming)
                return self.createSuccessResult(for: event, newTiming: newTiming, newEndDate: newEndDate, command: command)
            }
        )
    }

    // MARK: - Common Result Creation

    private func createSuccessResult(
        for event: EventOccurrence,
        newTiming: Date,
        newEndDate: Date,
        command: CommandContext
    ) -> ToolResult {
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
}
