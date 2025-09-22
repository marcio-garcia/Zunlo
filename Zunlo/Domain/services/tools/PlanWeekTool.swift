//
//  PlanWeekTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Plan Week Tool

/// Tool for planning and viewing weekly schedules
final class PlanWeekTool: ActionTool {
    private let events: EventStore
    private let calendar: Calendar

    init(events: EventStore, calendar: Calendar = .appDefault) {
        self.events = events
        self.calendar = calendar
    }

    // MARK: - ActionTool Conformance

    func perform(_ command: CommandContext) async -> ToolResult {
        do {
            guard let weekRange = command.temporalContext.dateRange, command.temporalContext.isRangeQuery else {
                return ToolResult(
                    intent: command.intent,
                    action: .none,
                    needsDisambiguation: false,
                    options: [],
                    message: "Failed to load week plan: no relevant range"
                )
            }

            let dateRange = weekRange.toDateRange()
            let occurrences = try await events.fetchOccurrences(in: dateRange)

            return ToolResult(
                intent: command.intent,
                action: .plannedWeek(range: dateRange, occurrences: occurrences),
                needsDisambiguation: false,
                options: [],
                message: formatWeekPlan(for: weekRange, occurrences: occurrences)
            )

        } catch {
            return ToolResult(
                intent: command.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: "Failed to load week plan: \(error.localizedDescription)"
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

//    private func createWeekRange(for date: Date) -> Range<Date> {
//        let startOfWeek = date.startOfWeek(calendar: calendar)
//        let endOfWeek = startOfWeek.endOfWeek(calendar: calendar)
//        return startOfWeek..<endOfWeek
//    }

    private func formatWeekPlan(for interval: DateInterval, occurrences: [EventOccurrence]) -> String {
        let weekStart = interval.start
        let weekEnd = interval.end

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let weekRange = "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"

        if occurrences.isEmpty {
            return String(format: "No events scheduled for the week of %@.".localized, weekRange)
        }

        // Group events by day
        let groupedEvents = Dictionary(grouping: occurrences) { event in
            event.startDate.startOfDay(calendar: calendar)
        }

        let sortedDays = groupedEvents.keys.sorted()
        let dayPlans = sortedDays.map { day in
            let dayEvents = groupedEvents[day]?.sorted { $0.startDate < $1.startDate } ?? []

            let dayFormatter = DateFormatter()
            dayFormatter.calendar = calendar
            dayFormatter.dateStyle = .short
            dayFormatter.timeStyle = .none

            let dayName = dayFormatter.string(from: day)
            let eventList = dayEvents.map { event in
                let timeFormatter = DateFormatter()
                timeFormatter.calendar = calendar
                timeFormatter.timeStyle = .short
                timeFormatter.dateStyle = .none

                let timeString = timeFormatter.string(from: event.startDate)
                return "  • \(timeString): \(event.title)"
            }.joined(separator: "\n")

            return "\(dayName):\n\(eventList)"
        }.joined(separator: "\n\n")

        return String(format: "Week plan (%@):\n\n%@".localized, weekRange, dayPlans)
    }
}
