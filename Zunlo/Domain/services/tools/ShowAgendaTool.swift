//
//  ShowAgendaTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Show Agenda Tool

/// Tool for displaying agenda view of events
final class ShowAgendaTool: ActionTool {
    private let events: EventStore
    private let calendar: Calendar

    init(events: EventStore, calendar: Calendar = .appDefault) {
        self.events = events
        self.calendar = calendar
    }

    // MARK: - ActionTool Conformance

    func perform(_ command: CommandContext) async -> ToolResult {
        do {
            let timeRange = extractTimeRange(from: command)
            let occurrences = try await events.fetchOccurrences(in: timeRange)

            return ToolResult(
                intent: command.intent,
                action: .agenda(range: timeRange, occurrences: occurrences),
                needsDisambiguation: false,
                options: [],
                message: formatAgenda(for: timeRange, occurrences: occurrences)
            )

        } catch {
            return ToolResult(
                intent: command.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: "Failed to load agenda: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Helper Methods

    private func extractTimeRange(from command: CommandContext) -> Range<Date> {
        let context = command.temporalContext

        if let dateRange = context.dateRange {
            return dateRange.start..<dateRange.end
        }

        // Default to current day if no range specified
        let targetDate = context.finalDate
        let startOfDay = targetDate.startOfDay(calendar: calendar)
        let endOfDay = startOfDay.endOfDay(calendar: calendar)
        return startOfDay..<endOfDay
    }

    private func formatAgenda(for range: Range<Date>, occurrences: [EventOccurrence]) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let startDate = formatter.string(from: range.lowerBound)
        let endDate = formatter.string(from: range.upperBound)

        let rangeText = Calendar.current.isDate(range.lowerBound, inSameDayAs: range.upperBound) ?
            startDate :
            "\(startDate) - \(endDate)"

        if occurrences.isEmpty {
            return String(format: "No events in your agenda for %@.".localized, rangeText)
        }

        let sortedEvents = occurrences.sorted { $0.startDate < $1.startDate }

        // Group by date for multi-day ranges
        let groupedEvents = Dictionary(grouping: sortedEvents) { event in
            event.startDate.startOfDay(calendar: calendar)
        }

        if groupedEvents.count == 1 {
            // Single day - simple list
            let eventList = sortedEvents.map { event in
                formatEventForAgenda(event)
            }.joined(separator: "\n")

            return String(format: "Agenda for %@:\n\n%@".localized, rangeText, eventList)
        } else {
            // Multiple days - group by date
            let sortedDays = groupedEvents.keys.sorted()
            let dayAgendas = sortedDays.map { day in
                let dayEvents = groupedEvents[day]?.sorted { $0.startDate < $1.startDate } ?? []

                let dayFormatter = DateFormatter()
                dayFormatter.calendar = calendar
                dayFormatter.dateStyle = .full
                dayFormatter.timeStyle = .none

                let dayName = dayFormatter.string(from: day)
                let eventList = dayEvents.map { event in
                    "  \(formatEventForAgenda(event))"
                }.joined(separator: "\n")

                return "\(dayName):\n\(eventList)"
            }.joined(separator: "\n\n")

            return String(format: "Agenda (%@):\n\n%@".localized, rangeText, dayAgendas)
        }
    }

    private func formatEventForAgenda(_ event: EventOccurrence) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        let startTime = timeFormatter.string(from: event.startDate)
        let endTime = timeFormatter.string(from: event.endDate)

        var eventText = "• \(startTime) - \(endTime): \(event.title)"

        if let location = event.location, !location.isEmpty {
            eventText += " @ \(location)"
        }

        if event.isCancelled {
            eventText += " (Cancelled)".localized
        }

        return eventText
    }
}
