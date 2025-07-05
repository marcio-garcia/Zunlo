//
//  EventOccurrenceService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation

struct EventOccurrenceService {
    /// Generate all event occurrences (including overrides/cancellations) in the given range.
    static func generate(
        events: [Event],
        rules: [RecurrenceRule],
        overrides: [EventOverride],
        in range: ClosedRange<Date>
    ) -> [EventOccurrence] {
        var occurrences: [EventOccurrence] = []

        let ruleDict = Dictionary(grouping: rules, by: { $0.eventId })
        let overrideDict = Dictionary(grouping: overrides, by: { $0.eventId })

        for event in events {
            if !event.isRecurring {
                // Single event
                guard range.contains(event.startDate) else { continue }
                let isCancelled = overrides.contains(where: { $0.eventId == event.id && $0.occurrenceDate == event.startDate && $0.isCancelled })
                if !isCancelled {
                    // If there's an override for this one-off event, apply it
                    if let ov = overrides.first(where: { $0.eventId == event.id && $0.occurrenceDate == event.startDate }) {
                        occurrences.append(EventOccurrence(
                            id: ov.id,
                            eventId: event.id,
                            title: ov.overriddenTitle ?? event.title,
                            description: event.description,
                            startDate: ov.overriddenStartDate ?? event.startDate,
                            endDate: ov.overriddenEndDate ?? event.endDate,
                            location: ov.overriddenLocation ?? event.location,
                            isOverride: true,
                            isCancelled: false
                        ))
                    } else {
                        occurrences.append(EventOccurrence(
                            id: event.id,
                            eventId: event.id,
                            title: event.title,
                            description: event.description,
                            startDate: event.startDate,
                            endDate: event.endDate,
                            location: event.location,
                            isOverride: false,
                            isCancelled: false
                        ))
                    }
                }
            } else {
                // Recurring event
                guard let rule = ruleDict[event.id]?.first else { continue }
                let dates = generateRecurrenceDates(
                    start: event.startDate,
                    rule: rule,
                    within: range
                )
                let eventOverrides = overrideDict[event.id] ?? []

                for date in dates {
                    // Is there an override/cancellation?
                    if let ov = eventOverrides.first(where: { $0.occurrenceDate.isSameDay(as: date) }) {
                        if ov.isCancelled { continue }
                        occurrences.append(EventOccurrence(
                            id: ov.id, // The override's ID
                            eventId: event.id,
                            title: ov.overriddenTitle ?? event.title,
                            description: event.description,
                            startDate: ov.overriddenStartDate ?? date,
                            endDate: ov.overriddenEndDate ?? event.endDate,
                            location: ov.overriddenLocation ?? event.location,
                            isOverride: true,
                            isCancelled: false
                        ))
                    } else {
                        occurrences.append(EventOccurrence(
                            id: UUID(uuidString: "\(event.id.uuidString.prefix(8))\(date.timeIntervalSince1970)") ?? event.id,
                            eventId: event.id,
                            title: event.title,
                            description: event.description,
                            startDate: date,
                            endDate: event.endDate, // End time is not updated for recurring in this sample
                            location: event.location,
                            isOverride: false,
                            isCancelled: false
                        ))
                    }
                }
            }
        }

        // Optional: sort by date/time
        return occurrences.sorted { $0.startDate < $1.startDate }
    }

    /// Generate recurrence dates in the range.
    static func generateRecurrenceDates(start: Date, rule: RecurrenceRule, within range: ClosedRange<Date>) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        let interval = rule.interval

        switch rule.freq {
        case "daily":
            var date = start
            while date <= range.upperBound {
                if date >= range.lowerBound {
                    dates.append(date)
                }
                guard let next = calendar.date(byAdding: .day, value: interval, to: date) else { break }
                date = next
                if let until = rule.until, date > until { break }
                if let count = rule.count, dates.count >= count { break }
            }

        case "weekly":
            let weekdays = rule.byWeekday ?? [calendar.component(.weekday, from: start)]
            var date = start
            while date <= range.upperBound {
                for weekday in weekdays {
                    let nextDate = calendar.nextDate(after: date, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime, direction: .forward) ?? date
                    if nextDate >= range.lowerBound && nextDate <= range.upperBound {
                        dates.append(nextDate)
                    }
                }
                guard let next = calendar.date(byAdding: .weekOfYear, value: interval, to: date) else { break }
                date = next
                if let until = rule.until, date > until { break }
                if let count = rule.count, dates.count >= count { break }
            }

        case "monthly":
            let monthdays = rule.byMonthday ?? [calendar.component(.day, from: start)]
            var date = start
            while date <= range.upperBound {
                for day in monthdays {
                    var comps = calendar.dateComponents([.year, .month], from: date)
                    comps.day = day
                    if let nextDate = calendar.date(from: comps), nextDate >= range.lowerBound && nextDate <= range.upperBound {
                        dates.append(nextDate)
                    }
                }
                guard let next = calendar.date(byAdding: .month, value: interval, to: date) else { break }
                date = next
                if let until = rule.until, date > until { break }
                if let count = rule.count, dates.count >= count { break }
            }

        default:
            // Extend for "yearly", etc. as needed.
            break
        }

        return dates
    }
}
