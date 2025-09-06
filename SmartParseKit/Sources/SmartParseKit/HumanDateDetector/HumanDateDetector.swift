//
//  HumanDateDetector.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/6/25.
//

import Foundation

// MARK: - Policies

/// Policies for relative weekday phrases.
public struct RelativeWeekdayPolicy {
    public enum ThisPolicy {
        /// Resolve to the nearest upcoming occurrence, including today if it matches.
        case upcomingIncludingToday
        /// Resolve to the nearest upcoming occurrence, but never today (must be in the future).
        case upcomingExcludingToday
    }

    public enum NextPolicy {
        /// Resolve to the next occurrence (no forced 7-day skip).
        case immediateUpcoming
        /// Resolve to the occurrence after the next (always skip one full week).
        case skipOneWeek
    }

    public var this: ThisPolicy
    public var next: NextPolicy

    public init(this: ThisPolicy = .upcomingIncludingToday,
                next: NextPolicy = .immediateUpcoming) {
        self.this = this
        self.next = next
    }
}

// MARK: - Lexicon

/// Locale-aware lexicon of modifier/weekday words used to recognize phrases.
public struct RelativeLexicon {
    /// Words that mean "this"
    public var thisWords: [String]
    /// Words that mean "next"
    public var nextWords: [String]
    /// Localized weekday names (lowercased) mapped to Calendar weekday numbers (1=Sunday … 7=Saturday)
    public var weekdayToNumber: [String: Int]

    public init(thisWords: [String],
                nextWords: [String],
                weekdayToNumber: [String: Int]) {
        self.thisWords = thisWords
        self.nextWords = nextWords
        self.weekdayToNumber = weekdayToNumber
    }

    /// pt-BR–tuned defaults (falls back to en/es minimal if not pt)
    public static func `default`(calendar: Calendar = .current, locale: Locale = .current) -> RelativeLexicon {
        var cal = calendar
        cal.locale = locale

        let full = cal.weekdaySymbols.map { $0.lowercased() }               // domingo, segunda-feira, ...
        let short = cal.shortWeekdaySymbols.map { $0.lowercased() }         // dom, seg, ...
        let veryShort = cal.veryShortWeekdaySymbols.map { $0.lowercased() } // d, s, ...

        var map: [String: Int] = [:]
        for w in 1...7 {
            let f = full[w - 1]
            let s = short[w - 1]
            let v = veryShort[w - 1]
            map[f] = w
            map[s] = w
            map[v] = w
            // Portuguese variants: remove hyphen from “segunda-feira”
            let noHyphen = f.replacingOccurrences(of: "-", with: " ")
            if noHyphen != f { map[noHyphen] = w }
            // Common “sem -feira” shorthand: “segunda”, “terca”, “terça”, “quarta”, “quinta”, “sexta”
            if f.contains("segunda") { map["segunda"] = w }
            if f.contains("terça") || f.contains("terca") { map["terça"] = w; map["terca"] = w }
            if f.contains("quarta") { map["quarta"] = w }
            if f.contains("quinta") { map["quinta"] = w }
            if f.contains("sexta") { map["sexta"] = w }
        }

        let lang = locale.identifier.lowercased()
        if lang.hasPrefix("pt") {
            // “this” and “next” word lists for pt-BR
            let thisWords = [
                "este", "esta", "neste", "nesta", "deste", "desta",
                "agora", "nessa", "nesta"
            ]
            let nextWords = [
                "próximo", "proximo", "no próximo", "no proximo",
                "na próxima", "na proxima", "seguinte"
            ]
            return .init(thisWords: thisWords, nextWords: nextWords, weekdayToNumber: map)
        }

        // Fallback (en/es kept minimal)
        let thisWords = ["this", "coming", "este", "esta"]
        let nextWords = ["next", "próximo", "proximo", "siguiente"]
        return .init(thisWords: thisWords, nextWords: nextWords, weekdayToNumber: map)
    }
}

// MARK: - Detector

/// A thin wrapper around NSDataDetector that fixes "this/next [weekday]" semantics (pt-BR tuned).
public final class HumanDateDetector {
    public struct Match {
        public let date: Date
        public let timeZone: TimeZone?
        public let duration: TimeInterval?
        public let range: Range<String.Index>
        public let original: NSTextCheckingResult
        public let overridden: Bool
    }

    private let detector: NSDataDetector
    private let timeZone: TimeZone
    private let policy: RelativeWeekdayPolicy
    var calendar: Calendar
    let lexicon: RelativeLexicon
    let regex: NSRegularExpression
    lazy var weekdayQueVemRegex: NSRegularExpression = {
        let weekdayAlt = lexicon.weekdayToNumber.keys
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern)
            .joined(separator: "|")
        let pattern = #"\b(\#(weekdayAlt))\s+que\s+vem\b"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// - Parameters:
    ///   - calendar: Calendar used for computations (locale is respected).
    ///   - timeZone: Force a timezone when none is present in the match. Defaults to calendar.timeZone.
    ///   - policy: How to interpret "this" and "next".
    ///   - lexicon: Words/weekday map to detect relative phrases.
    public init(calendar: Calendar = .current,
                timeZone: TimeZone? = nil,
                policy: RelativeWeekdayPolicy = .init(),
                lexicon: RelativeLexicon = .default()) {

        self.detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        var cal = calendar
        cal.timeZone = timeZone ?? calendar.timeZone
        self.calendar = cal
        self.timeZone = cal.timeZone
        self.policy = policy
        self.lexicon = lexicon

        // Build a case-insensitive regex like:  (THIS|NEXT words) [opt article] <weekday> [opt "que vem"]
        let thisAlt = lexicon.thisWords.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let nextAlt = lexicon.nextWords.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let weekdayAlt = lexicon.weekdayToNumber.keys
            .sorted { $0.count > $1.count } // prefer longer matches first
            .map(NSRegularExpression.escapedPattern)
            .joined(separator: "|")

        let pattern = #"""
        \b(
            (?:\#(thisAlt))|
            (?:\#(nextAlt))
          )
          \s+(?:o|a|no|na|neste|nesta|deste|desta)?\s*
          (\#(weekdayAlt))
          (?:\s+que\s+vem)?
        \b
        """#
        self.regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .allowCommentsAndWhitespace])
    }

    /// Find dates in `text`, overriding ambiguous relative weekdays per policy.
    public func matches(in text: String, base: Date = Date()) -> [Match] {
        let fullRange = NSRange(text.startIndex..., in: text)
        var results: [Match] = []

        detector.enumerateMatches(in: text, options: [], range: fullRange) { raw, _, _ in
            guard let raw, raw.resultType == .date, let date = raw.date,
                  var r = Range(raw.range, in: text) else { return }

            if let override = overriddenDateIfRelativeWeekday(phrase: text.lowercased(),
                                                              base: base,
                                                              detectedDate: date,
                                                              range: &r) {
                // Preserve time components from detectedDate, apply to override day.
                let final = self.applyTime(of: date, toDayOf: override)
                results.append(.init(date: final,
                                     timeZone: raw.timeZone ?? self.timeZone,
                                     duration: raw.duration,
                                     range: r,
                                     original: raw,
                                     overridden: true))
            } else {
                results.append(.init(date: date,
                                     timeZone: raw.timeZone ?? self.timeZone,
                                     duration: raw.duration,
                                     range: r,
                                     original: raw,
                                     overridden: false))
            }
        }
        return results
    }

    // MARK: - Internals

    private func overriddenDateIfRelativeWeekday(
        phrase: String,
        base: Date,
        detectedDate: Date,
        range: inout Range<String.Index>
    ) -> Date? {
        var nsRange = NSRange(range, in: phrase)
        
        var m = regex.firstMatch(in: phrase, options: [], range: nsRange)
        
        // expand range's lower bound to check if the detector excluded the "next" word
        var newRange: Range<String.Index>?
        if m == nil {
            let newLower = phrase.index(range.lowerBound, offsetBy: -24, limitedBy: phrase.startIndex) ?? phrase.startIndex
            newRange = newLower..<range.upperBound
            nsRange = NSRange(newRange!, in: phrase)
        }
        
        m = regex.firstMatch(in: phrase, options: [], range: nsRange)
        
        if let m = regex.firstMatch(in: phrase, options: [], range: nsRange) {
            range = newRange ?? range
            let mod = substring(phrase, m.range(at: 1))
            let weekdayStr = substring(phrase, m.range(at: 2))
            guard let weekday = lexicon.weekdayToNumber[weekdayStr] else { return nil }
            return resolve(modifierToken: mod, weekday: weekday, base: base)
        }

        // e.g. "domingo que vem" (implicit 'next')
        if let m2 = weekdayQueVemRegex.firstMatch(in: phrase, options: [], range: nsRange) {
            let weekdayStr = substring(phrase, m2.range(at: 1))
            guard let weekday = lexicon.weekdayToNumber[weekdayStr] else { return nil }
            return resolve(modifierToken: "próximo", weekday: weekday, base: base) // treat as "next"
        }

        return nil
    }

    private func resolve(modifierToken: String, weekday: Int, base: Date) -> Date? {
        let baseStart = calendar.startOfDay(for: base)
        let todayW = calendar.component(.weekday, from: baseStart)

        func nextOccurrence(of weekday: Int, includingToday: Bool) -> Date {
            if includingToday && weekday == todayW { return baseStart }
            return calendar.nextDate(after: baseStart,
                                     matching: DateComponents(weekday: weekday),
                                     matchingPolicy: .nextTime,
                                     direction: .forward)!
        }

        if matchesAny(modifierToken, in: lexicon.thisWords) {
            switch policy.this {
            case .upcomingIncludingToday:
                return nextOccurrence(of: weekday, includingToday: true)
            case .upcomingExcludingToday:
                let first = nextOccurrence(of: weekday, includingToday: false)
                return calendar.isDate(first, inSameDayAs: baseStart) ? calendar.date(byAdding: .day, value: 7, to: first)! : first
            }
        } else {
            // treat any other match (e.g., próximo / “que vem”) as NEXT
            switch policy.next {
            case .immediateUpcoming:
                return nextOccurrence(of: weekday, includingToday: false)
            case .skipOneWeek:
                let first = nextOccurrence(of: weekday, includingToday: false)
                return calendar.date(byAdding: .weekOfYear, value: 1, to: first)!
            }
        }
    }

    private func applyTime(of source: Date, toDayOf day: Date) -> Date {
        let comps = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: source)
        var dayComps = calendar.dateComponents([.year, .month, .day], from: day)
        dayComps.hour = comps.hour
        dayComps.minute = comps.minute
        dayComps.second = comps.second
        dayComps.nanosecond = comps.nanosecond
        return calendar.date(from: dayComps)!
    }

    internal func substring(_ s: String, _ range: NSRange) -> String {
        guard let r = Range(range, in: s) else { return "" }
        return String(s[r])
    }

    internal func matchesAny(_ token: String, in set: [String]) -> Bool {
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return set.contains { t == $0.lowercased() }
    }
}
