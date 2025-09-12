//
//  Utils.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/3/25.
//

import Foundation

@inline(__always)
func weekRange(containing date: Date, calendar: Calendar = .current) -> Range<Date> {
    var start = Date()
    var interval: TimeInterval = 0
    _ = calendar.dateInterval(of: .weekOfYear, start: &start, interval: &interval, for: date)
    return start..<(start.addingTimeInterval(interval))
}

@inline(__always)
func nextWeekRange(from date: Date, calendar: Calendar = .current) -> Range<Date> {
    let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: date)!
    return weekRange(containing: nextWeek, calendar: calendar)
}

@inline(__always)
func applyTime(calendar: Calendar, of source: Date, toDayOf day: Date) -> Date {
    let comps = calendar.dateComponents([.hour, .minute, .second], from: source)
    var dayComps = calendar.dateComponents([.year, .month, .day], from: day)
    dayComps.hour = comps.hour
    dayComps.minute = comps.minute
    dayComps.second = comps.second
    return calendar.date(from: dayComps) ?? day
}

@inline(__always)
func substring(_ s: String, _ ns: NSRange) -> String {
    guard ns.location != NSNotFound, let r = Range(ns, in: s) else { return "" }
    return String(s[r])
}

@inline(__always)
func matchesAny(_ token: String, in set: [String]) -> Bool {
    let t = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return set.contains { t == $0.lowercased() }
}

func containsAny(in s: String, of words: [String]) -> Bool {
    let l = s.lowercased()
    return words.contains { l.contains($0.lowercased()) }
}

// De-dup: prefer earlier textual range; unify exact same (date, duration) & overlapping ranges.
func dedup(_ items: [Match], text: String) -> [Match] {
    var out: [Match] = []
    for m in items {
        appendUnique(&out, m, text: text)
    }
    return out
}

func appendUnique(_ arr: inout [Match], _ m: Match, text: String) {
    let k1 = m.date.timeIntervalSinceReferenceDate
    let k2 = m.duration ?? -1
    let nsR = NSRange(m.range, in: text)
    for e in arr {
        let sameTime = abs(e.date.timeIntervalSinceReferenceDate - k1) < 0.5
        let sameDur  = ((e.duration ?? -1) - k2).magnitude < 0.5
        let overlap  = NSIntersectionRange(NSRange(e.range, in: text), nsR).length > 0
        if (sameTime && sameDur) || overlap { return } // skip duplicate-ish
    }
    arr.append(m)
}

/// Calculates the elapsed seconds between two "time-of-day" DateComponents
/// (e.g., hour/minute/second), anchored to a specific day in a given Calendar.
/// If the computed `end` time is earlier than `start`, `end` is rolled to the next day.
///
/// - Parameters:
///   - start: The starting time as DateComponents (hour/minute/second/nanosecond). Missing parts default to 0.
///   - end:   The ending time as DateComponents (hour/minute/second/nanosecond). Missing parts default to 0.
///   - day:   The day to anchor both times on (defaults to today).
///   - calendar: The calendar to use (timezone-sensitive). Defaults to `.current`.
///   - rollEndToNextDayWhenEarlier: If true, and `end < start`, moves `end` forward by 1 day. Defaults to true.
/// - Returns: The elapsed time in seconds as `TimeInterval`.
/// - Throws:  If any provided components are outside valid ranges (e.g., hour: 0...23).
public func secondsBetween(
    _ start: DateComponents,
    _ end: DateComponents,
    on day: Date = Date(),
    calendar: Calendar = .current,
    rollEndToNextDayWhenEarlier: Bool = true
) throws -> TimeInterval {

    func validate(_ c: DateComponents) throws {
        if let h = c.hour, !(0...23).contains(h) { throw NSError(domain: "TimeOfDay", code: 1, userInfo: [NSLocalizedDescriptionKey: "hour must be 0...23"]) }
        if let m = c.minute, !(0...59).contains(m) { throw NSError(domain: "TimeOfDay", code: 2, userInfo: [NSLocalizedDescriptionKey: "minute must be 0...59"]) }
        if let s = c.second, !(0...59).contains(s) { throw NSError(domain: "TimeOfDay", code: 3, userInfo: [NSLocalizedDescriptionKey: "second must be 0...59"]) }
        if let ns = c.nanosecond, !(0...999_999_999).contains(ns) {
            throw NSError(domain: "TimeOfDay", code: 4, userInfo: [NSLocalizedDescriptionKey: "nanosecond must be 0...999,999,999"])
        }
    }

    try validate(start)
    try validate(end)

    let baseDay = calendar.startOfDay(for: day)

    // Build a safe "anchored" date for a time-of-day on baseDay, handling DST gaps/duplicates.
    func anchoredDate(for time: DateComponents) -> Date {
        var t = DateComponents()
        t.hour = time.hour ?? 0
        t.minute = time.minute ?? 0
        t.second = time.second ?? 0
        t.nanosecond = time.nanosecond ?? 0

        // Use nextDate to respect DST: .nextTime moves through nonexistent times,
        // .first picks the first instance for repeated times (fall-back).
        if let d = calendar.nextDate(
            after: baseDay,
            matching: t,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) {
            return d
        }

        // Fallback should basically never happen with valid components.
        return baseDay
    }

    let startDate = anchoredDate(for: start)
    var endDate = anchoredDate(for: end)

    if rollEndToNextDayWhenEarlier, endDate < startDate {
        endDate = calendar.date(byAdding: .day, value: 1, to: endDate)!
    }

    return endDate.timeIntervalSince(startDate)
}
