//
//  UpdateEventTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Update Event Tool

/// Tool for updating events with enhanced candidate selection
final class UpdateEventTool: BaseEventTool, ActionTool {

    private let referenceDate: Date
    
    init(events: EventStore, referenceDate: Date, calendar: Calendar = .appDefault) {
        self.referenceDate = referenceDate
        super.init(events: events, calendar: calendar)
    }

    // MARK: - ActionTool Conformance

    func perform(_ command: CommandContext) async -> ToolResult {
        do {
            // 1. Fetch all events
            let allEvents = try await events.fetchOccurrences()

            // Check if user selected a specific entity
            if let id = command.selectedEntityId, let event = allEvents.first(where: { $0.id == id }) {
                return await self.performEventUpdate(event, command: command)
            }

            // 2. Pre-filter events for update context
            let relevantEvents = filterEventsByDate(
                allEvents,
                context: command,
                excludeCancelled: true,
                allowPastEvents: true,
                pastEventToleranceHours: 24.0,
                referenceDate: referenceDate
            )

            // 3. Use enhanced picker for better candidate selection
            let selection = eventPicker.selectEventCandidate(
                from: relevantEvents,
                for: command,
                intent: .updateEvent,
                referenceDate: referenceDate
            )

            // 4. Handle selection based on confidence
            return await handleEventSelection(selection, context: command, intent: .updateEvent) { event in
                await self.performEventUpdate(event, command: command)
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

    // MARK: - Event Updating

    private func performEventUpdate(
        _ event: EventOccurrence,
        command: CommandContext
    ) async -> ToolResult {

        do {
            let updateInfo = extractUpdateInfo(from: command, originalEvent: event)

            if event.isRecurring {
                // For recurring events, always ask for scope clarification
                let parent = try await fetchParentOccurrence(for: event)
                let opts = try buildScopeOptions(
                    for: event,
                    parent: parent,
                    parseResultId: command.id,
                    intent: command.intent,
                    actionLabels: (
                        single: "Update only this occurrence".localized,
                        future: "Update this and future occurrences".localized,
                        all: "Update all occurrences".localized
                    )
                )

                return ToolResult(
                    intent: command.intent,
                    action: .targetEventOccurrence(eventId: event.id, start: event.startDate),
                    needsDisambiguation: true,
                    options: opts,
                    message: "Do you want to update just this occurrence or the entire series?".localized
                )
            } else {
                // Single event - update directly
                let editInput = buildEditInput(
                    from: event,
                    newStart: updateInfo.newStart ?? event.startDate,
                    newEnd: updateInfo.newEnd ?? event.endDate,
                    newTitle: updateInfo.newTitle,
                    newLocation: updateInfo.newLocation,
                    newReminders: updateInfo.newReminders
                )

                try await events.editAll(
                    event: event,
                    with: editInput,
                    oldRule: nil
                )

                return ToolResult(
                    intent: command.intent,
                    action: .updatedEvent(id: event.id),
                    needsDisambiguation: false,
                    options: [],
                    message: String(format: "Updated '%@'.".localized, updateInfo.newTitle ?? event.title)
                )
            }
        } catch {
            return ToolResult(
                intent: command.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: "Failed to update event: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Update Info Extraction

    private struct UpdateInfo {
        let newTitle: String?
        let newLocation: String?
        let newStart: Date?
        let newEnd: Date?
        let newReminders: [ReminderTrigger]?
    }

    private func extractUpdateInfo(from command: CommandContext, originalEvent: EventOccurrence) -> UpdateInfo {
        let context = command.temporalContext
        var newTitle: String?
        var newLocation: String?
        var newReminders: [ReminderTrigger] = []

        // Extract metadata from metadataTokens
        for token in command.metadataTokens {
            switch token.kind {
            case .newTitle(let title, _):
                newTitle = title

            case .location(let name, _):
                newLocation = name

            case .reminder(let trigger, _):
                var timeBeforeDue: TimeInterval = 0
                var message: String?

                switch trigger {
                case .timeOffset(let offset):
                    timeBeforeDue = offset

                case .absoluteTime(let time):
                    let offset = time.timeIntervalSince(originalEvent.startDate)
                    timeBeforeDue = offset

                case .location(let location):
                    message = location
                }
                let reminder = ReminderTrigger(timeBeforeDue: timeBeforeDue, message: message)
                newReminders.append(reminder)

            default:
                break // Other cases are for tasks
            }
        }

        // Extract new timing if provided
        var newStart: Date?
        var newEnd: Date?

        if let dateRange = context.dateRange, dateRange.start != originalEvent.startDate {
            newStart = dateRange.start
            newEnd = dateRange.end
        } else if context.finalDate != originalEvent.startDate {
            let duration = originalEvent.endDate.timeIntervalSince(originalEvent.startDate)
            newStart = context.finalDate
            newEnd = context.finalDate.addingTimeInterval(duration)
        }

        return UpdateInfo(
            newTitle: newTitle,
            newLocation: newLocation,
            newStart: newStart,
            newEnd: newEnd,
            newReminders: newReminders.isEmpty ? nil : newReminders
        )
    }
}
