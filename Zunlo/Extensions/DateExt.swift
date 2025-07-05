//
//  DateExt.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

extension Date {
    
    static var formatter: DateFormatter = {
        let df = DateFormatter()
        return df
    }()
    
    static let isoFormatter = ISO8601DateFormatter()
    
    static var isoWithFractionalSeconds: DateFormatter = {
        Date.formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        Date.formatter.locale = Locale(identifier: "en_US_POSIX")
        Date.formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return Date.formatter
    }()
    
    func formattedDate(dateFormat: String) -> String {
        Date.formatter.dateFormat = dateFormat
        Date.formatter.locale = Locale(identifier: "en_US_POSIX")
        return Date.formatter.string(from: self)
    }
}

extension Date {
    func isSameDay(as other: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: other)
    }
}

extension Date {
    func settingTimeFrom(_ source: Date) -> Date {
        let cal = Calendar.current
        let components = cal.dateComponents([.hour, .minute, .second], from: source)
        return cal.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            of: self
        ) ?? self
    }
}

extension DateFormatter {
    static let iso8601WithFractionalSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static let iso8601WithoutFractionalSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
