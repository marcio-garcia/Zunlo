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

import Foundation

/// Elapsed seconds between two DateComponents representing times of day,
/// respecting any explicit **date** (year/month/day) present in either component.
/// - If both `start` and `end` include Y/M/D, those dates are used as-is (no rolling).
/// - If only one includes Y/M/D, that date anchors **both** times.
/// - If neither includes Y/M/D, both are anchored to `baseDay`.
/// - If at least one side lacked a date and the computed `end` is earlier than `start`,
///   `end` is rolled forward by 1 day when `rollEndToNextDayWhenEarlier` is `true`.
///
/// DST-safe: uses Calendar APIs that handle nonexistent/ambiguous times (spring-forward / fall-back).
///
/// Missing time fields default to 0.
/// Validation ensures hour/minute/second/nanosecond are in range.
/// Uses the provided `calendar` (and its `timeZone`) consistently.
///
/// - Parameters:
///   - start: Start time as DateComponents (optionally including Y/M/D).
///   - end: End time as DateComponents (optionally including Y/M/D).
///   - baseDay: Day to anchor when a side lacks Y/M/D (defaults to `Date()`).
///   - calendar: Calendar to use (timezone-sensitive). Defaults to `.current`.
///   - rollEndToNextDayWhenEarlier: If true, rolls `end` to the next day when earlier than `start`
///     and **at least one** side lacked Y/M/D. Defaults to true.
/// - Returns: Elapsed seconds as `TimeInterval`.
/// - Throws: `NSError` if components are invalid or an impossible date is formed.
public func secondsBetween(
    _ start: DateComponents,
    _ end: DateComponents,
    baseDay: Date = Date(),
    calendar: Calendar = .current,
    rollEndToNextDayWhenEarlier: Bool = true
) throws -> TimeInterval {

    // MARK: - Validation
    func validate(_ c: DateComponents) throws {
        if let h = c.hour, !(0...23).contains(h) {
            throw NSError(domain: "TimeOfDay", code: 1, userInfo: [NSLocalizedDescriptionKey: "hour must be 0...23"])
        }
        if let m = c.minute, !(0...59).contains(m) {
            throw NSError(domain: "TimeOfDay", code: 2, userInfo: [NSLocalizedDescriptionKey: "minute must be 0...59"])
        }
        if let s = c.second, !(0...59).contains(s) {
            throw NSError(domain: "TimeOfDay", code: 3, userInfo: [NSLocalizedDescriptionKey: "second must be 0...59"])
        }
        if let ns = c.nanosecond, !(0...999_999_999).contains(ns) {
            throw NSError(domain: "TimeOfDay", code: 4, userInfo: [NSLocalizedDescriptionKey: "nanosecond must be 0...999,999,999"])
        }
    }
    try validate(start)
    try validate(end)

    // MARK: - Helpers
    func hasYMD(_ c: DateComponents) -> Bool {
        c.year != nil && c.month != nil && c.day != nil
    }

    func startOfDay(fromY y: Int, m: Int, d: Int) throws -> Date {
        var ymd = DateComponents()
        ymd.year = y; ymd.month = m; ymd.day = d
        let midnight = calendar.date(from: ymd)
        guard let day = midnight.map({ calendar.startOfDay(for: $0) }) else {
            throw NSError(domain: "TimeOfDay", code: 5, userInfo: [NSLocalizedDescriptionKey: "invalid Y/M/D in components"])
        }
        return day
    }

    // Build an anchored date on a given "day", setting hour/minute/second/nanosecond safely w.r.t. DST.
    func setTimeOfDay(_ time: DateComponents, on day: Date) throws -> Date {
        let h = time.hour ?? 0
        let m = time.minute ?? 0
        let s = time.second ?? 0
        // Set H/M/S on that specific day. Use policies to handle nonexistent/ambiguous times.
        guard var result = calendar.date(bySettingHour: h,
                                         minute: m,
                                         second: s,
                                         of: day,
                                         matchingPolicy: .nextTime,
                                         repeatedTimePolicy: .first,
                                         direction: .forward) else {
            // Extremely unlikely with valid inputs, but be defensive.
            throw NSError(domain: "TimeOfDay", code: 6, userInfo: [NSLocalizedDescriptionKey: "failed to set time on day"])
        }
        if let ns = time.nanosecond {
            // Set nanoseconds precisely if provided.
            result = calendar.date(bySetting: .nanosecond, value: ns, of: result) ?? result.addingTimeInterval(Double(ns) / 1e9)
        }
        return result
    }

    // MARK: - Determine anchor days respecting provided dates
    let startHasDate = hasYMD(start)
    let endHasDate   = hasYMD(end)

    let baseDayStart = calendar.startOfDay(for: baseDay)

    let startAnchorDay: Date = {
        if startHasDate, let y = start.year, let m = start.month, let d = start.day {
            return (try? startOfDay(fromY: y, m: m, d: d)) ?? baseDayStart
        } else if endHasDate, let y = end.year, let m = end.month, let d = end.day {
            // Anchor start to end's date if only end has Y/M/D
            return (try? startOfDay(fromY: y, m: m, d: d)) ?? baseDayStart
        } else {
            // Neither has a date, use baseDay
            return baseDayStart
        }
    }()

    let endAnchorDay: Date = {
        if endHasDate, let y = end.year, let m = end.month, let d = end.day {
            return (try? startOfDay(fromY: y, m: m, d: d)) ?? baseDayStart
        } else if startHasDate, let y = start.year, let m = start.month, let d = start.day {
            // Anchor end to start's date if only start has Y/M/D
            return (try? startOfDay(fromY: y, m: m, d: d)) ?? baseDayStart
        } else {
            // Neither has a date, use baseDay
            return baseDayStart
        }
    }()

    // MARK: - Build concrete Dates
    let startDate = try setTimeOfDay(start, on: startAnchorDay)
    var endDate   = try setTimeOfDay(end,   on: endAnchorDay)

    // Only roll if at least one side lacked Y/M/D (i.e., the "same-day unless earlier" semantics)
    if rollEndToNextDayWhenEarlier, (!startHasDate || !endHasDate), endDate < startDate {
        guard let rolled = calendar.date(byAdding: .day, value: 1, to: endDate) else {
            throw NSError(domain: "TimeOfDay", code: 7, userInfo: [NSLocalizedDescriptionKey: "failed to roll end to next day"])
        }
        endDate = rolled
    }

    return endDate.timeIntervalSince(startDate)
}
