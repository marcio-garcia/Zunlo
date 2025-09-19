//
//  CreateEventTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Create Event Tool

/// Tool for creating new events
final class CreateEventTool: BaseEventTool, ActionTool {
//    private let events: EventStore
//    private let calendar: Calendar
    private let userId: UUID
    
    init(events: EventStore, userId: UUID, calendar: Calendar = .appDefault) {
        self.userId = userId
        super.init(events: events, calendar: calendar)
    }

    // MARK: - ActionTool Conformance

    func perform(_ command: ParseResult) async -> ToolResult {
        do {
            let eventInfo = extractEventInfo(from: command)

            let eventInput = AddEventInput(
                id: UUID(),
                userId: userId,
                title: eventInfo.title,
                notes: eventInfo.notes,
                startDate: eventInfo.startDate,
                endDate: eventInfo.endDate,
                isRecurring: eventInfo.isRecurring,
                location: eventInfo.location,
                color: eventInfo.color,
                reminderTriggers: eventInfo.reminderTriggers,
                recurrenceType: eventInfo.recurrenceType,
                recurrenceInterval: eventInfo.recurrenceInterval,
                byWeekday: eventInfo.byWeekday,
                byMonthday: eventInfo.byMonthday,
                until: eventInfo.until,
                count: eventInfo.count,
                isCancelled: false
            )

            try await events.add(eventInput)

            return ToolResult(
                intent: command.intent,
                action: .createdEvent(id: UUID()), // Note: AddEventInput doesn't return ID
                needsDisambiguation: false,
                options: [],
                message: String(format: "Created event '%@'.".localized, eventInfo.title)
            )

        } catch {
            return ToolResult(
                intent: command.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: "Failed to create event: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Event Info Extraction

    private struct EventInfo {
        let title: String
        let notes: String?
        let startDate: Date
        let endDate: Date
        let isRecurring: Bool
        let location: String?
        let color: EventColor
        let reminderTriggers: [ReminderTrigger]
        let recurrenceType: String?
        let recurrenceInterval: Int?
        let byWeekday: [Int]?
        let byMonthday: [Int]?
        let until: Date?
        let count: Int?
    }

    private func extractEventInfo(from command: ParseResult) -> EventInfo {
        let context = command.context
        var notes: String?
        var location: String?
        var reminderTriggers: [ReminderTrigger] = []

        // Extract metadata from metadataTokens
        for token in command.metadataTokens {
            switch token.kind {
            case .notes(let noteText, _):
                notes = noteText
            case .location(let name, _):
                location = name
            case .reminder(let trigger, _):
                var timeBeforeDue: TimeInterval = 0
                var message: String?

                switch trigger {
                case .timeOffset(let offset):
                    timeBeforeDue = offset
                case .absoluteTime(let time):
                    timeBeforeDue = time.timeIntervalSince(context.finalDate)
                case .location(let loc):
                    message = loc
                }

                let reminder = ReminderTrigger(timeBeforeDue: timeBeforeDue, message: message)
                reminderTriggers.append(reminder)
            default:
                break
            }
        }

        // Extract timing
        let startDate: Date
        let endDate: Date

        if let dateRange = context.dateRange {
            startDate = dateRange.start
            endDate = dateRange.end
        } else {
            startDate = context.finalDate
            // Default to 1 hour duration
            endDate = startDate.addingTimeInterval(3600)
        }

        // Extract recurrence if present
        let recurrence: RecurrenceRule? = nil
        let isRecurring = recurrence != nil

        // Use title from command or fallback
        let title = !command.title.isEmpty ? command.title : "New Event".localized

        return EventInfo(
            title: title,
            notes: notes,
            startDate: startDate,
            endDate: endDate,
            isRecurring: false,
            location: location,
            color: EventColor.softOrange,
            reminderTriggers: reminderTriggers,
            recurrenceType: recurrence?.freq.rawValue,
            recurrenceInterval: recurrence?.interval,
            byWeekday: recurrence?.byWeekday,
            byMonthday: recurrence?.byMonthday,
            until: recurrence?.until,
            count: recurrence?.count
        )
    }
}
