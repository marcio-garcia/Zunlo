//
//  Date+Range.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

extension Date {
    static func clamp(_ value: Date, to range: Range<Date>) -> Date {
        min(max(value, range.lowerBound), range.upperBound)
    }

    func isSameDay(as other: Date, calendar: Calendar = .appDefault) -> Bool {
        return calendar.isDate(self, inSameDayAs: other)
    }
    
    func startOfDay(calendar: Calendar = .appDefault) -> Date {
        return calendar.startOfDay(for: self)
    }

    func startOfNextDay(calendar: Calendar = .appDefault) -> Date {
        let dayStart = self.startOfDay(calendar: calendar)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        return nextDay
    }
    
    func endOfDay(calendar: Calendar = .appDefault) -> Date {
        let nextDay = self.startOfNextDay(calendar: calendar)
        return calendar.date(byAdding: .second, value: -1, to: nextDay)!
    }
    
    func daysInterval(to date2: Date) -> Int {
        let cal = Calendar.appDefault
        let components = cal.dateComponents([.day], from: self, to: date2)
        if let days = components.day {
            return days
        }
        return 0
    }
}

public extension Date {
    /// Start of the week that contains this date, in the given calendar.
    /// Returns midnight at the beginning of that week (local to `calendar.timeZone`).
    func startOfWeek(calendar: Calendar = .current) -> Date {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: self) else {
            // Extremely rare (non-Gregorian edge cases) — fall back to start of this day.
            return calendar.startOfDay(for: self)
        }
        return calendar.startOfDay(for: interval.start)
    }

    /// End of the week that contains this date, in the given calendar.
    /// Returns the last representable moment *before* the next week begins (inclusive end).
    func endOfWeek(calendar: Calendar = .current) -> Date {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: self),
              let lastMoment = calendar.date(byAdding: .nanosecond, value: -1, to: interval.end) else {
            // Fall back to the end of this day.
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: self))!
            return calendar.date(byAdding: .nanosecond, value: -1, to: startOfTomorrow)!
        }
        return lastMoment
    }
}
