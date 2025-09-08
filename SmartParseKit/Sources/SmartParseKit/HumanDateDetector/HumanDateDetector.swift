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

    public init(this: ThisPolicy = .upcomingExcludingToday,
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
    public static func current(calendar: Calendar = .current, locale: Locale = .current) -> RelativeLexicon {
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

/// A thin wrapper around NSDataDetector that:
/// 1) fixes "this/next [weekday]" semantics (pt-BR tuned),
/// 2) adds synthetic matches for "this/next week" / "semana que vem" / "esta semana" / "plan my week" etc.
public final class HumanDateDetector {
    public struct Match {
        public let date: Date
        public let timeZone: TimeZone?
        public let duration: TimeInterval?
        public let range: Range<String.Index>
        public let original: NSTextCheckingResult?   // nil for synthetic week matches
        public let overridden: Bool                  // true if we overrode or synthesized
    }

    private let detector: NSDataDetector
    private let timeZone: TimeZone
    private let policy: RelativeWeekdayPolicy
    var calendar: Calendar
    let lexicon: RelativeLexicon

    // ----- Weekday phrase regexes -----
    let regex: NSRegularExpression
    lazy var weekdayQueVemRegex: NSRegularExpression = {
        let weekdayAlt = lexicon.weekdayToNumber.keys
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern)
            .joined(separator: "|")
        let pattern = #"\b(\#(weekdayAlt))\s+que\s+vem\b"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    // ----- Week phrase regexes -----
    // e.g., "esta semana", "próxima semana", "semana que vem", "this week", "next week"
    internal let weekMainRegex: NSRegularExpression
    // e.g., bare "week" / "semana" in task-like phrasing: "plan my week", "minha semana", "agenda da semana"
    internal let weekBareRegex: NSRegularExpression

    /// - Parameters:
    ///   - calendar: Calendar used for computations (locale is respected).
    ///   - timeZone: Force a timezone when none is present in the match. Defaults to calendar.timeZone.
    ///   - policy: How to interpret "this" and "next".
    ///   - lexicon: Words/weekday map to detect relative phrases.
    public init(calendar: Calendar = .current,
                timeZone: TimeZone? = nil,
                policy: RelativeWeekdayPolicy = .init(),
                lexicon: RelativeLexicon = .current()) {

        self.detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        var cal = calendar
        cal.timeZone = timeZone ?? calendar.timeZone
        self.calendar = cal
        self.timeZone = cal.timeZone
        self.policy = policy
        self.lexicon = lexicon

        // Build a case-insensitive regex like:  (THIS|NEXT words) [opt article] <weekday> [opt "que vem"] --- Weekday regex (this/next <weekday> [que vem]) ---
        let thisAlt = lexicon.thisWords.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let nextAlt = lexicon.nextWords.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let weekdayAlt = lexicon.weekdayToNumber.keys
            .sorted { $0.count > $1.count } // prefer longer matches first
            .map(NSRegularExpression.escapedPattern)
            .joined(separator: "|")

        let weekdayPattern = #"""
        (?iu)\b(?:(
            (?:\#(thisAlt))|
            (?:\#(nextAlt))
          )
          \s+(?:o|a|no|na|neste|nesta|deste|desta)?\s*
          )?
          (\#(weekdayAlt))
          (?:\s+que\s+vem)?
        \b
        """#
        self.regex = try! NSRegularExpression(pattern: weekdayPattern, options: [.caseInsensitive, .allowCommentsAndWhitespace])

        // --- Week regexes ---
        let weekWords = #"semana|week"#
        let weekMainPattern = #"""
        \b(
            (?:\#(thisAlt))|
            (?:\#(nextAlt))|
            (?:que\s+vem)        # supports "<something> que vem" when preceded by "semana"
        )
        \s*(?:a|o|na|no|desta|deste|nesta|neste)?\s*
        (?:\#(weekWords))
        \b
        """#
        self.weekMainRegex = try! NSRegularExpression(pattern: weekMainPattern, options: [.caseInsensitive, .allowCommentsAndWhitespace])

        // "Bare" week cues (no explicit this/next): plan my week / minha semana / agenda da semana / this agenda week-ish)
        let weekBarePattern = #"""
        (?x)
        \b(?:
            plan(?:\s+my)?\s+week |
            agenda\s+(?:da|de|para)\s+semana |
            minha\s+semana |
            meu\s+planejamento\s+da\s+semana |
            (?:the\s+)?week\b |
            \bsemana\b
        )
        """#
        self.weekBareRegex = try! NSRegularExpression(pattern: weekBarePattern, options: [.caseInsensitive])
    }

    /// Find dates/ranges in `text`, overriding ambiguous relative weekdays and adding week ranges.
    public func matches(in text: String, base: Date = Date()) -> [Match] {
        let fullRange = NSRange(text.startIndex..., in: text)
        var results: [Match] = []

        // 1) Normal NSDataDetector dates (then possibly override weekday phrases)
        detector.enumerateMatches(in: text, options: [], range: fullRange) { raw, _, _ in
            guard let raw, raw.resultType == .date, let date = raw.date else { return }
            guard var r = Range(raw.range, in: text) else { return }
            
            if let override = overriddenDateIfRelativeWeekday(in: text,
                                                              base: base,
                                                              detectedDate: date,
                                                              range: &r) {
                // Preserve time components from detectedDate, apply to override day.
                let final = applyTime(calendar: calendar, of: date, toDayOf: override)
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

        // 2) Synthetic "week" ranges that NSDataDetector misses.
        results.append(contentsOf: weekRangeMatches(in: text, base: base))

        // Sort by range start for deterministic order
        results.sort { lhs, rhs in
            lhs.range.lowerBound < rhs.range.lowerBound
        }

        return results
    }

    // MARK: - Internals (weekday overrides)

    private func overriddenDateIfRelativeWeekday(
        in text: String,
        base: Date,
        detectedDate: Date,
        range: inout Range<String.Index>
    ) -> Date? {
        // Work with NSRange against the ORIGINAL text
        var nsRange = NSRange(range, in: text)

        // Try immediate match in the current range
        var match = regex.firstMatch(in: text, options: [], range: nsRange)

        // If none, expand the LEFT side a bit to include a possible skipped modifier (e.g., “next”)
        if match == nil {
            let newLower = text.index(range.lowerBound, offsetBy: -24, limitedBy: text.startIndex) ?? text.startIndex
            let expanded = newLower..<range.upperBound
            nsRange = NSRange(expanded, in: text)
            match = regex.firstMatch(in: text, options: [], range: nsRange)
            if match != nil { range = expanded } // keep range in sync with text
        }

        if let m = match {
            let mod = substring(text, m.range(at: 1))
            let weekdayStr = substring(text, m.range(at: 2))
            if let weekday = lexicon.weekdayToNumber[weekdayStr.lowercased()] {
                return resolve(modifierToken: mod, weekday: weekday, base: base)
            }
        }

        // Try "<weekday> que vem" as implicit NEXT, in the SAME text/range
        if let m2 = weekdayQueVemRegex.firstMatch(in: text, options: [], range: nsRange) {
            let weekdayStr = substring(text, m2.range(at: 1))
            if let weekday = lexicon.weekdayToNumber[weekdayStr.lowercased()] {
                return resolve(modifierToken: "próximo", weekday: weekday, base: base)
            }
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

    // MARK: - Internals (week phrases)

    /// Creates synthetic matches for week phrases with a 1-week duration starting at the calendar's week start.
    private func weekRangeMatches(in text: String, base: Date) -> [Match] {
        var out: [Match] = []
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        func addMatch(range nsRange: NSRange, start: Date, interval: TimeInterval) {
            guard let r = Range(nsRange, in: text) else { return }
            out.append(.init(date: start,
                             timeZone: timeZone,
                             duration: interval,
                             range: r,
                             original: nil,
                             overridden: true))
        }

        // Compute this week's start + length
        let (thisWeekStart, thisWeekInterval) = weekStartAndInterval(containing: base)
        let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: thisWeekStart)!
        let // usually 7d; use same interval as this week for consistency
            nextWeekInterval = thisWeekInterval

        // A) Explicit "this/next week" (incl. "semana que vem")
        weekMainRegex.enumerateMatches(in: text, options: [], range: full) { m, _, _ in
            guard let m = m else { return }
            let phrase = ns.substring(with: m.range).lowercased()

            // If phrase contains an explicit NEXT cue ("next" / "próximo" / "que vem" / etc.), use next week; else this week.
            let isNext =
                containsAny(in: phrase, of: lexicon.nextWords) ||
                phrase.contains("que vem") ||
                phrase.contains("next")

            if isNext {
                addMatch(range: m.range, start: nextWeekStart, interval: nextWeekInterval)
            } else {
                addMatch(range: m.range, start: thisWeekStart, interval: thisWeekInterval)
            }
        }

        // B) Bare week cues (interpret as "this week")
        weekBareRegex.enumerateMatches(in: text, options: [], range: full) { m, _, _ in
            guard let m = m else { return }
            // Avoid duplicating a range we've already added from the main regex
            let alreadyCovered = out.contains { existing in
                let a = NSRange(existing.range, in: text)
                return NSIntersectionRange(a, m.range).length > 0
            }
            if !alreadyCovered {
                addMatch(range: m.range, start: thisWeekStart, interval: thisWeekInterval)
            }
        }

        return out
    }

    private func weekStartAndInterval(containing date: Date) -> (Date, TimeInterval) {
        var start = Date()
        var interval: TimeInterval = 0
        _ = calendar.dateInterval(of: .weekOfYear, start: &start, interval: &interval, for: date)
        // `interval` accounts for DST transitions if any.
        return (start, interval)
    }
}
