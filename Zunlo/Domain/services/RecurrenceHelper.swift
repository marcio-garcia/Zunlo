//
//  RecurrenceHelper.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/6/25.
//

import Foundation

class RecurrenceHelper {
    
    /// Weekdays use Calendar convention: 1=Sunday, 2=Monday, ..., 7=Saturday.

    static func generateRecurrenceDates(
        start: Date,
        rule: RecurrenceRule,
        within range: ClosedRange<Date>,
        calendar: Calendar = .current
    ) -> [Date] {
        switch rule.freq {
        case "daily":
            return generateDailyRecurrence(start: start, rule: rule, within: range, calendar: calendar)
        case "weekly":
            return generateWeeklyRecurrence(start: start, rule: rule, within: range, calendar: calendar)
        case "monthly":
            return generateMonthlyRecurrence(start: start, rule: rule, within: range, calendar: calendar)
        default:
            // Extend for yearly, etc.
            return []
        }
    }

    private static func generateDailyRecurrence(
        start: Date,
        rule: RecurrenceRule,
        within range: ClosedRange<Date>,
        calendar: Calendar
    ) -> [Date] {
        var dates: [Date] = []
        let interval = max(1, rule.interval)
        var date = start
        let untilDate = rule.until?.startOfNextDay()
        var occurrences = 0
        while true {
            occurrences += 1
            if date >= range.lowerBound && date <= range.upperBound {
                dates.append(date)
            }
            if let count = rule.count, occurrences >= count { break }
            guard let next = calendar.date(byAdding: .day, value: interval, to: date) else { break }
            date = next
            if let until = untilDate, date >= until { break }
            if rule.count == nil, date > range.upperBound { break }
        }
        return dates.sorted()
    }

    private static func generateWeeklyRecurrence(
        start: Date,
        rule: RecurrenceRule,
        within range: ClosedRange<Date>,
        calendar: Calendar
    ) -> [Date] {
        var dates: [Date] = []
        let interval = max(1, rule.interval)
        let weekdays = rule.byWeekday ?? [calendar.component(.weekday, from: start)]
        var weekStart = calendar.dateInterval(of: .weekOfYear, for: start)!.start
        let untilDate = rule.until?.startOfNextDay()
        var occurrences = 0
        while true {
            for weekday in weekdays.sorted() {
                if let nextDate = calendar.nextDate(
                    after: weekStart.addingTimeInterval(-1),
                    matching: DateComponents(hour: calendar.component(.hour, from: start),
                                            minute: calendar.component(.minute, from: start),
                                            weekday: weekday),
                    matchingPolicy: .nextTime
                ),
                nextDate >= weekStart
                {
                    occurrences += 1
                    if nextDate >= range.lowerBound && nextDate <= range.upperBound {
                        if dates.last != nextDate {
                            dates.append(nextDate)
                        }
                    }
                    if let count = rule.count, occurrences >= count { return dates.sorted() }
                    if let until = untilDate, nextDate >= until { return dates.sorted() }
                }
            }
            if let count = rule.count, occurrences >= count { break }
            guard let next = calendar.date(byAdding: .weekOfYear, value: interval, to: weekStart) else { break }
            weekStart = next
            if let until = untilDate, weekStart >= until { break }
            if rule.count == nil, weekStart > range.upperBound { break }
        }
        return dates.sorted()
    }

    private static func generateMonthlyRecurrence(
        start: Date,
        rule: RecurrenceRule,
        within range: ClosedRange<Date>,
        calendar: Calendar
    ) -> [Date] {
        var dates: [Date] = [start]
        let interval = max(1, rule.interval)
        let monthdays = rule.byMonthday ?? [calendar.component(.day, from: start)]
        var date = start
        let untilDate = rule.until?.startOfNextDay()
        var occurrences = 0
        while true {
            for day in monthdays.sorted() {
                var comps = calendar.dateComponents([.year, .month], from: date)
                comps.day = day
                comps.hour = calendar.component(.hour, from: start)
                comps.minute = calendar.component(.minute, from: start)
                if let nextDate = calendar.date(from: comps),
                   calendar.component(.month, from: nextDate) == comps.month,
                   calendar.component(.year, from: nextDate) == comps.year,
                   nextDate >= start
                {
                    occurrences += 1
                    if nextDate >= range.lowerBound && nextDate <= range.upperBound {
                        dates.append(nextDate)
                    }
                    if let count = rule.count, occurrences >= count { return dates.sorted() }
                    if let until = untilDate, nextDate >= until { return dates.sorted() }
                }
            }
            if let count = rule.count, occurrences >= count { break }
            guard let next = calendar.date(byAdding: .month, value: interval, to: date) else { break }
            date = next
            if let until = untilDate, date >= until { break }
            if rule.count == nil, date > range.upperBound { break }
        }
        return dates.sorted()
    }
    
    static func addTodayIfNeeded(occurrences: [EventOccurrence]) -> [EventOccurrence] {
        let today = Date().startOfDay
        var hasToday = false
        
        for occ in occurrences where occ.startDate.isSameDay(as: today) {
            hasToday = true
        }
        
        if !hasToday {
            var occ = occurrences
            occ.append(EventOccurrence(
                id: UUID(),
                userId: UUID(),
                eventId: UUID(),
                title: String(localized: "Nothing for today"),
                description: nil,
                startDate: today,
                endDate: nil,
                isRecurring: false,
                location: nil,
                color: EventColor.yellow,
                isOverride: false,
                isCancelled: false,
                updatedAt: today,
                createdAt: today,
                overrides: [],
                recurrence_rules: [],
                isFakeOccForEmptyToday: true)
            )
            return occ
        }
        
        return occurrences
    }
}
