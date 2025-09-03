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
    
    func startOfNextDay(calendar: Calendar = .appDefault) -> Date {
        let dayStart = self.startOfDay(calendar: calendar)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        return nextDay
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
