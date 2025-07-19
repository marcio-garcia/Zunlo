//
//  DateExt.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

extension Date {
    enum DateFormat: String {
        case regular = "dd MMM YYYY"
        case dayMonth = "dd MMM"
        case monthName = "LLLL"
        case time = "HH:mm"
        case weekAndDay = "E d"
    }
    
    static var format = DateFormat.regular
    
    static var formatter: DateFormatter = {
        let df = DateFormatter()
        return df
    }()
    
    static var isoWithFractionalSeconds: DateFormatter = {
        Date.formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        Date.formatter.locale = Locale(identifier: "en_US_POSIX")
        Date.formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return Date.formatter
    }()
    
    func formattedDate(dateFormat: DateFormat) -> String {
        return formattedDate(format: dateFormat.rawValue)
    }
    
    func formattedDate(format: String) -> String {
        Date.formatter.dateFormat = format
        Date.formatter.locale = Locale(identifier: "en_US_POSIX")
        return Date.formatter.string(from: self)
    }
    
    static func formattedDate(from string: String, format: String) -> Date? {
        Date.formatter.dateFormat = format
        Date.formatter.locale = Locale(identifier: "en_US_POSIX")
        Date.formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return Date.formatter.date(from: string)
    }
}

extension Date {
    func isSameDay(as other: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: other)
    }
    
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
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
    
    func stripTime(calendar: Calendar = .event) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day], from: self)
        return calendar.date(from: comps)!
    }
}
