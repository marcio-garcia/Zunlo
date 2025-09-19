//
//  PlanDayTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Plan Day Tool

/// Tool for planning and viewing daily schedules
final class PlanDayTool: ActionTool {
    private let events: EventStore
    private let calendar: Calendar

    init(events: EventStore, calendar: Calendar = .appDefault) {
        self.events = events
        self.calendar = calendar
    }

    // MARK: - ActionTool Conformance

    func perform(_ command: ParseResult) async -> ToolResult {
        do {
            let targetDate = extractTargetDate(from: command)
            let dayRange = createDayRange(for: targetDate)

            let occurrences = try await events.fetchOccurrences(in: dayRange)

            return ToolResult(
                intent: command.intent,
                action: .plannedDay(range: dayRange, occurrences: occurrences),
                needsDisambiguation: false,
                options: [],
                message: formatDayPlan(for: targetDate, occurrences: occurrences)
            )

        } catch {
            return ToolResult(
                intent: command.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: "Failed to load day plan: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Helper Methods

    private func extractTargetDate(from command: ParseResult) -> Date {
        let context = command.context

        if let dateRange = context.dateRange {
            return dateRange.start
        }

        return context.finalDate
    }

    private func createDayRange(for date: Date) -> Range<Date> {
        let startOfDay = date.startOfDay(calendar: calendar)
        let endOfDay = date.endOfDay(calendar: calendar)
        return startOfDay..<endOfDay
    }

    private func formatDayPlan(for date: Date, occurrences: [EventOccurrence]) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateStyle = .full
        formatter.timeStyle = .none

        let dayName = formatter.string(from: date)

        if occurrences.isEmpty {
            return String(format: "No events scheduled for %@.".localized, dayName)
        }

        let sortedEvents = occurrences.sorted { $0.startDate < $1.startDate }
        let eventList = sortedEvents.map { event in
            let timeFormatter = DateFormatter()
            timeFormatter.calendar = calendar
            timeFormatter.timeStyle = .short
            timeFormatter.dateStyle = .none

            let timeString = timeFormatter.string(from: event.startDate)
            return "• \(timeString): \(event.title)"
        }.joined(separator: "\n")

        return String(format: "Schedule for %@:\n%@".localized, dayName, eventList)
    }
}
