//
//  DateExtraction.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

// MARK: - Date Extraction

import Foundation

public struct DateParseResult {
    public var dates: [Date] = []
    public var duration: TimeInterval = 0
}

public func extractDates(_ text: String, locale: Locale = .current) -> DateParseResult {
    let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    var out = DateParseResult()
    let ns = text as NSString
//    detector.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
//        guard let m = match, m.resultType == .date else { return }
//        out.duration = m.duration
//        if let d = m.date {
//            out.dates.append(d)
//        }
//    }
    let matches = detector.matches(in: text, range: NSRange(location: 0, length: ns.length)).filter { $0.resultType == .date }
    for match in matches {
        out.duration = match.duration
    }
    
    let patchedDate = patchedDetectedDate(from: text, base: Date(), tz: .current, locale: locale)
    return out
}

/// Use this instead of the raw NSDataDetector date when you want
/// “next Friday” = strictly the next occurrence after `base`.
func patchedDetectedDate(from text: String,
                         base: Date = Date(),
                         tz: TimeZone = .current,
                         locale: Locale = .current) -> Date? {
    // 1) Let NSDataDetector try first.
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    let matches = detector?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
    var detected = matches.first(where: { $0.resultType == .date })?.date

    // If it clearly says “next week”, don’t override semantics.
    let low = text.lowercased()
    let saysNextWeek = low.contains("next week") || low.contains("próxima semana") || low.contains("proxima semana")

    // 2) If it’s the bare “next <weekday>” flavor, override to strictly upcoming.
    if !saysNextWeek {
        if let wd = captureWeekdayEn(text) ?? captureWeekdayPt(text) {
            detected = strictlyNext(weekday: wd, after: base, tz: tz)
        }
    }
    return detected
}

//struct DateSpan { var start: Date; var end: Date?; var timeZone: TimeZone }
//
//func parseDates(_ text: String, tz: TimeZone, policy: Policy) throws -> [DateSpan] {
//    let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
//    let matches = withTimeZone(tz) { detector.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) }
//    var out: [DateSpan] = []
//
//    for m in matches where m.resultType == .date {
//        let detectedTZ = m.timeZone ?? tz
//        let base = m.date
//        let adjustedStart = policy.rewriteRelativeIfNeeded(match: m, base: base, tz: detectedTZ) // e.g., strict “next Friday”
//        let span = policy.coerceRangeIfNeeded(match: m, start: adjustedStart, tz: detectedTZ)     // ensure end > start, roll to next day, etc.
//        out.append(span)
//    }
//    return out
//}

private let reNextWeekdayEn = try! NSRegularExpression(
  pattern: #"(?i)\bnext\s+(mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b"#
)

private let reNextWeekdayPt = try! NSRegularExpression(
  pattern: #"(?i)\b(?:próxima|proxima|que\s+vem)\s+(segunda(?:-feira)?|ter[cç]a(?:-feira)?|quarta(?:-feira)?|quinta(?:-feira)?|sexta(?:-feira)?|sábado|sabado|domingo)\b|\b(segunda|ter[cç]a|quarta|quinta|sexta)(?:-feira)?\s+(?:próxima|proxima|que\s+vem)\b"#
)

private func captureWeekdayEn(_ text: String) -> Int? {
    guard let m = reNextWeekdayEn.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
          let r = Range(m.range(at: 1), in: text) else { return nil }
    return weekdayIndexEn(String(text[r]))
}

private func captureWeekdayPt(_ text: String) -> Int? {
    // Try both capturing groups (pattern allows either order)
    if let m = reNextWeekdayPt.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
        for i in 1..<m.numberOfRanges {
            if let r = Range(m.range(at: i), in: text) {
                if let wd = weekdayIndexPt(String(text[r])) { return wd }
            }
        }
    }
    return nil
}

/// 1=Sun ... 7=Sat (Calendar/Gregorian convention)
private func weekdayIndexEn(_ s: String) -> Int? {
    switch s.prefix(3).lowercased() {
    case "sun": return 1
    case "mon": return 2
    case "tue": return 3
    case "wed": return 4
    case "thu": return 5
    case "fri": return 6
    case "sat": return 7
    default: return nil
    }
}

private func weekdayIndexPt(_ s: String) -> Int? {
    let t = s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    if t.hasPrefix("domingo") { return 1 }
    if t.hasPrefix("segunda") { return 2 }
    if t.hasPrefix("terca")   { return 3 }
    if t.hasPrefix("quarta")  { return 4 }
    if t.hasPrefix("quinta")  { return 5 }
    if t.hasPrefix("sexta")   { return 6 }
    if t.hasPrefix("sab")     { return 7 } // sábado
    return nil
}

/// Strictly the next occurrence after `base` (never “today”).
private func strictlyNext(weekday: Int, after base: Date, tz: TimeZone) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    var comps = DateComponents()
    comps.weekday = weekday
    // nextDate with .nextTime returns the next match strictly forward
    return cal.nextDate(after: base, matching: comps, matchingPolicy: .nextTime, direction: .forward)!
}
