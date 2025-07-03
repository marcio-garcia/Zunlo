//
//  Array+Event.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/2/25.
//

import Foundation

extension Array where Element == Event {
    func allEventDates(in range: ClosedRange<Date>) -> [Date] {
        let cal = Calendar.current
        var allDates = Set<Date>()

        for event in self {
            let start = cal.startOfDay(for: event.dueDate)
            switch event.recurrence {
            case .none:
                if range.contains(start) {
                    allDates.insert(start)
                }
            case .daily:
                var day = Swift.max(start, range.lowerBound)
                while day <= range.upperBound {
                    allDates.insert(day)
                    guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                    day = next
                }
            case .weekly(let weekday):
                // Find first matching weekday >= lowerBound
                var day = Swift.max(start, range.lowerBound)
                while cal.component(.weekday, from: day) != weekday {
                    guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                    day = next
                    if day > range.upperBound { break }
                }
                while day <= range.upperBound {
                    allDates.insert(day)
                    guard let next = cal.date(byAdding: .weekOfYear, value: 1, to: day) else { break }
                    day = next
                }
            case .monthly(let monthDay):
                var comps = cal.dateComponents([.year, .month], from: Swift.max(start, range.lowerBound))
                comps.day = monthDay
                var day = cal.date(from: comps) ?? start
                while day < range.lowerBound {
                    // Next month
                    comps.month = (comps.month ?? 1) + 1
                    if comps.month! > 12 {
                        comps.month = 1
                        comps.year! += 1
                    }
                    day = cal.date(from: comps) ?? day
                }
                while day <= range.upperBound {
                    // Only add if the day matches the month
                    if (cal.component(.month, from: day) == comps.month) {
                        allDates.insert(day)
                    }
                    comps.month = (comps.month ?? 1) + 1
                    if comps.month! > 12 {
                        comps.month = 1
                        comps.year! += 1
                    }
                    day = cal.date(from: comps) ?? day
                }
            }
        }
        return allDates.sorted()
    }
}
