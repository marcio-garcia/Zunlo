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

public func extractDates(_ text: String, base: Date = Date(), locale: Locale = .current) -> DateParseResult {
    let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    var out = DateParseResult()
    let ns = text as NSString

    let matches = detector.matches(in: text, range: NSRange(location: 0, length: ns.length)).filter { $0.resultType == .date }
    for match in matches {
        out.duration = match.duration
        if let date = match.date {
            out.dates.append(date)
        }
    }
    
    // Calculate “next Friday” = strictly the next occurrence after `base`.
    // This is because NSDataDetector returns "next Friday" as the real next Friday + 7
    if out.dates.count == 1
        && (findWeekdayEn(text) != nil || findWeekdayPt(text) != nil) {
        
        // If it clearly says “next week”, don’t override semantics.
        let low = text.lowercased()
        let saysNextWeek = low.contains("next week") || low.contains("próxima semana") || low.contains("proxima semana")

        // 2) If it’s the bare “next <weekday>” flavor, override to strictly upcoming.
        if !saysNextWeek {
            if let wd = captureWeekdayEn(text) ?? captureWeekdayPt(text) {
                let detected = strictlyNext(weekday: wd, after: base, tz: TimeZone.gmt)
                out.dates.removeAll()
                out.dates.append(detected)
            }
        }
    }
    
    return out
}

private let reNextWeekdayEn = try! NSRegularExpression(
  pattern: #"(?i)\bnext\s+(mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b"#
)

private let reNextWeekdayPt = try! NSRegularExpression(
  pattern: #"(?i)\b(?:próxima|proxima|que\s+vem)\s+(segunda(?:-feira)?|ter[cç]a(?:-feira)?|quarta(?:-feira)?|quinta(?:-feira)?|sexta(?:-feira)?|sábado|sabado|domingo)\b|\b(segunda|ter[cç]a|quarta|quinta|sexta)(?:-feira)?\s+(?:próxima|proxima|que\s+vem)\b"#
)

private func findWeekdayEn(_ text: String) -> NSTextCheckingResult? {
    guard let m = reNextWeekdayEn.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text))
    else { return nil }
    return m
}

private func findWeekdayPt(_ text: String) -> NSTextCheckingResult? {
    guard let m = reNextWeekdayPt.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text))
    else { return nil }
    return m
}

private func captureWeekdayEn(_ text: String) -> Int? {
    guard let m = findWeekdayEn(text),
          let r = Range(m.range(at: 1), in: text) else { return nil }
    return weekdayIndexEn(String(text[r]))
}

private func captureWeekdayPt(_ text: String) -> Int? {
    // Try both capturing groups (pattern allows either order)
    if let m = findWeekdayPt(text) {
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
    let t = s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    switch t.prefix(3).lowercased() {
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
    switch t.prefix(3).lowercased() {
    case "dom": return 1
    case "seg": return 2
    case "ter": return 3
    case "qua": return 4
    case "qui": return 5
    case "sex": return 6
    case "sab": return 7
    default: return nil
    }
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
