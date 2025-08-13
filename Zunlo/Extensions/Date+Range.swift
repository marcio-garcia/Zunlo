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
    
    func startOfNextDay() -> Date {
        let tz = TimeZone.current
        var cal = Calendar.appDefault
        cal.timeZone = tz

        let dayStart = self.startOfDay
        let nextDay = cal.date(byAdding: .day, value: 1, to: dayStart)!

        return nextDay
    }
}
