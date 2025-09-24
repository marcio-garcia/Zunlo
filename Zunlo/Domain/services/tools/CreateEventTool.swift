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

    func perform(_ context: CommandContext) async -> ToolResult {
        do {
            let eventInfo = extractEventInfo(from: context)

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
                intent: context.intent,
                action: .createdEvent(id: eventInput.id),
                needsDisambiguation: false,
                options: [],
                message: String(format: String(localized: "Created event '%@'."), eventInfo.title)
            )

        } catch {
            return ToolResult(
                intent: context.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: String(localized: "Failed to create event: \(error.localizedDescription)")
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

    private func extractEventInfo(from context: CommandContext) -> EventInfo {
        let temporalContext = context.temporalContext
        var newTitle: String?
        var notes: String?
        var location: String?
        var reminderTriggers: [ReminderTrigger] = []

        // Extract metadata from metadataTokens
        for token in context.metadataTokens {
            switch token.kind {
            case .newTitle(let title, _):
                newTitle = title
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
                    timeBeforeDue = time.timeIntervalSince(context.temporalContext.finalDate)
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
        var endDate: Date

//        if let dateRange = context.dateRange {
//            startDate = dateRange.start
//            endDate = dateRange.end
//        } else {
        startDate = context.temporalContext.finalDate
        endDate = startDate.addingTimeInterval(3600) // Default to 1 hour duration
        if let duration = context.temporalContext.finalDateDuration {
            endDate = startDate.addingTimeInterval(duration)
        }
//        }

        // Extract recurrence if present
        let recurrence: RecurrenceRule? = nil
        let isRecurring = recurrence != nil

        // Use title from context or fallback
        var title: String = context.title
        if let t = newTitle {
            title = t
        }

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
