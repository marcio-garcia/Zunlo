//
//  DateExt.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

enum RFC3339 {
    // 6 fractional digits, UTC, POSIX
    static let micro: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .iso8601)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        return df
    }()

    static let isoMillis: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds] // ms
        return f
    }()

    static let isoNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

enum RFC3339Lossless {
    // yyyy-MM-dd'T'HH:mm:ss(.fraction)?(Z|±HH:MM)
    private static let regex: NSRegularExpression = {
        let pattern = #"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?(Z|[+\-]\d{2}:\d{2})$"#
        return try! NSRegularExpression(pattern: pattern, options: [])
    }()

    private static let baseParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime] // no fractional seconds
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Parses RFC3339 with up to 9 fractional digits, preserving precision.
    static func parse(_ s: String) -> Date? {
        let ns = s as NSString
        guard let m = regex.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        let base = ns.substring(with: m.range(at: 1)) + ns.substring(with: m.range(at: 3))
        guard let baseDate = baseParser.date(from: base) else { return nil }

        let fracRange = m.range(at: 2)
        guard fracRange.location != NSNotFound else { return baseDate }

        // Pad to nanoseconds and add to base
        let frac = ns.substring(with: fracRange)                 // 1..9 digits
        let nanosStr = frac.padding(toLength: 9, withPad: "0", startingAt: 0)
        guard let nanos = Int(nanosStr) else { return baseDate }
        let adjusted = baseDate.addingTimeInterval(Double(nanos) / 1_000_000_000)
        return adjusted
    }
}

extension Date {
    enum DateFormat: String {
        case time = "HH:mm"
        case day = "d"
        case week = "EEE"
        case year = "YYYY"
        case regular = "dd MMM YYYY"
        case dayMonth = "dd MMM"
        case monthName = "LLLL"
        case weekAndDay = "E d"
    }
    
    static var format = DateFormat.regular
    
    static var formatter: DateFormatter = {
        let df = DateFormatter()
        return df
    }()
    
    func formattedDate(
        dateFormat: DateFormat,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> String {
        return formattedDate(format: dateFormat.rawValue, locale: locale)
    }
    
    func formattedDate(
        format: String,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> String {
        Date.formatter.dateFormat = format
        Date.formatter.locale = locale
        return Date.formatter.string(from: self)
    }
    
    static func formattedDate(
        from string: String,
        format: String,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> Date? {
        Date.formatter.dateFormat = format
        Date.formatter.locale = locale
        Date.formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return Date.formatter.date(from: string)
    }
    
    // MARK: - ISO8601 helpers
    func iso8601() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: self)
    }

    /// Always emits 6 fractional digits, e.g. 2025-08-13T18:21:57.532031Z
    func rfc3339MicroString() -> String { RFC3339.micro.string(from: self) }
    
    func nextMillisecondCursor() -> String {
        let t = self.timeIntervalSince1970
        let bumped = (floor(t * 1000.0) + 1.0) / 1000.0 // add 1 ms
        return RFC3339.micro.string(from: Date(timeIntervalSince1970: bumped))
    }
    
    static func localDateToAI() -> String {
        let fmt = ISO8601DateFormatter()
        fmt.timeZone = .current
        fmt.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return fmt.string(from: Date()) // e.g. 2025-08-24T11:10:00-03:00
    }
}

extension Date {
    func isSameDay(as other: Date) -> Bool {
        let calendar = Calendar.appDefault
        return calendar.isDate(self, inSameDayAs: other)
    }
    
    var startOfDay: Date {
        return Calendar.appDefault.startOfDay(for: self)
    }
}

extension Date {
    func settingTimeFrom(_ source: Date) -> Date {
        let cal = Calendar.appDefault
        let components = cal.dateComponents([.hour, .minute, .second], from: source)
        return cal.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            of: self
        ) ?? self
    }
    
    func stripTime(calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day], from: self)
        return calendar.date(from: comps)!
    }
}
