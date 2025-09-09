//
//  HumanDateDetector.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/6/25.
//

import Foundation

struct PackBundle {
    let pack: DateLanguagePack
    let weekday: NSRegularExpression
    let weekMain: NSRegularExpression
    let weekBare: NSRegularExpression
    let inlineRange: NSRegularExpression
    let fromTo: NSRegularExpression
}

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
        public let ambiguous: Bool
        public let ambiguityReason: String?
    }

    private let timeZone: TimeZone
    private let policy: RelativeWeekdayPolicy
    private(set) var bundles: [PackBundle]
    private let dateDetector: DateDetecting
    var calendar: Calendar
    
    /// - Parameters:
    ///   - calendar: Calendar used for computations (locale is respected).
    ///   - timeZone: Force a timezone when none is present in the match. Defaults to calendar.timeZone.
    ///   - policy: How to interpret "this" and "next".
    ///   - packs: Language packages.
    public init(
        calendar: Calendar = .current,
        policy: RelativeWeekdayPolicy = .init(),
        packs: [DateLanguagePack],
        dateDetector: DateDetecting = AppleDateDetector()
    ) {
        self.calendar = calendar
        self.timeZone = calendar.timeZone
        self.policy = policy
        self.dateDetector = dateDetector
        self.bundles = packs.map { pack in
            PackBundle(
                pack: pack,
                weekday: pack.weekdayPhraseRegex(),
                weekMain: pack.weekMainRegex(),
                weekBare: pack.weekBareRegex(),
                inlineRange: pack.inlineTimeRangeRegex(),
                fromTo: pack.fromToTimeRegex()
            )
        }
    }

    /// Find dates/ranges in `text`, overriding ambiguous relative weekdays and adding week ranges.
    public func matches(in text: String, base: Date = Date()) -> [Match] {
        let fullRange = NSRange(text.startIndex..., in: text)
        var results: [Match] = []

        // 1) Normal NSDataDetector dates (then possibly override weekday phrases)
        dateDetector.enumerateMatches(in: text, range: fullRange) { raw in
            guard raw.resultType == .date, let date = raw.date else { return }
            guard var r = Range(raw.range, in: text) else { return }
            
            if let override = overriddenDateIfRelativeWeekday(in: text,
                                                              base: base,
                                                              detectedDate: date,
                                                              range: &r) {
                // Preserve time components from detectedDate, apply to override day.
                let final = applyTime(calendar: calendar, of: date, toDayOf: override)
                appendUnique(
                    &results,
                    Match(date: final,
                          timeZone: raw.timeZone ?? self.timeZone,
                          duration: raw.duration,
                          range: r,
                          original: raw,
                          overridden: true,
                          ambiguous: false,
                          ambiguityReason: nil),
                    text: text)
                            
            } else {
                appendUnique(
                    &results,
                    Match(date: date,
                          timeZone: raw.timeZone ?? self.timeZone,
                          duration: raw.duration,
                          range: r,
                          original: raw,
                          overridden: false,
                          ambiguous: false,
                          ambiguityReason: nil),
                    text: text)
            }
        }
        
        // 2) Synthetic "week" ranges that NSDataDetector misses.
        for b in bundles {
            results.append(contentsOf: weekRangeMatches(bundle: b, in: text, base: base))
        }

        // 3) Compact inline weekday+time ranges (e.g., "wed 9-10")
        for b in bundles {
            results.append(contentsOf: inlineTimeRangeMatches(bundle: b, in: text, base: base, policy: policy))
        }

        // 4) "from–to" with optional weekday (e.g., "quarta das 9 às 10", "from 9 to 10")
        for b in bundles {
            let matches = fromToTimeMatches(bundle: b, in: text, base: base)
            for match in matches {
                if results.isEmpty {
                    results.append(match)
                } else {
                    for (index, _) in results.enumerated() {
                        let final = applyTime(calendar: calendar, of: match.date, toDayOf: results[index].date)
                        results[index] = Match(date: final,
                                               timeZone: results[index].timeZone,
                                               duration: match.duration,
                                               range: results[index].range,
                                               original: results[index].original,
                                               overridden: true,
                                               ambiguous: false,
                                               ambiguityReason: nil)
                    }
                }
            }
        }

        // 5) Dedup ONLY exact duplicates; keep overlapping alternatives from different sources
        results = dedupExact(results, in: text)
        
        results.sort { $0.range.lowerBound < $1.range.lowerBound }
        return results
    }

    // MARK: - Internals (weekday overrides)
    
    private func overriddenDateIfRelativeWeekday(
        in text: String,
        base: Date,
        detectedDate: Date,
        range: inout Range<String.Index>
    ) -> Date? {
        for b in bundles {
            let (modifier, weekday, _) = extractModifierWeekdayOrWeek(in: text, around: range)
            if let w = weekday, modifier != .none {
                return resolve(modifierToken: modifier == .this ? b.pack.thisTokens.first ?? "" : b.pack.nextTokens.first ?? "",
                               weekday: w,
                               base: base,
                               pack: b.pack)
            }            
        }
        return nil
    }
    
    private func resolve(modifierToken: String, weekday: Int, base: Date, pack: DateLanguagePack) -> Date? {
        let baseStart = calendar.startOfDay(for: base)
        let todayW = calendar.component(.weekday, from: baseStart)
        
        func nextOccurrence(of weekday: Int, includingToday: Bool) -> Date {
            if includingToday && weekday == todayW { return baseStart }
            return calendar.nextDate(after: baseStart, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime, direction: .forward)!
        }

        if matchesAny(modifierToken, in: pack.thisTokens) {
            return (policy.this == .upcomingIncludingToday)
                ? nextOccurrence(of: weekday, includingToday: true)
                : {
                    let first = nextOccurrence(of: weekday, includingToday: false)
                    return calendar.isDate(first, inSameDayAs: baseStart) ? calendar.date(byAdding: .day, value: 7, to: first)! : first
                }()
        }
        if matchesAny(modifierToken, in: pack.nextTokens) || pack.phraseIndicatesNext(modifierToken.lowercased()) {
            switch policy.next {
            case .immediateUpcoming: return nextOccurrence(of: weekday, includingToday: false)
            case .skipOneWeek:
                let first = nextOccurrence(of: weekday, includingToday: false)
                return calendar.date(byAdding: .weekOfYear, value: 1, to: first)!
            }
        }
        // No modifier → treat like “this”
        return (policy.this == .upcomingIncludingToday)
            ? nextOccurrence(of: weekday, includingToday: true)
            : nextOccurrence(of: weekday, includingToday: false)
    }

    // MARK: - Internals (week phrases)

    /// Creates synthetic matches for week phrases with a 1-week duration starting at the calendar's week start.
    private func weekRangeMatches(bundle b: PackBundle, in text: String, base: Date) -> [Match] {
        var out: [Match] = []
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        func add(_ nsRange: NSRange, start: Date, interval: TimeInterval) {
            guard let r = Range(nsRange, in: text) else { return }
            appendUnique(
                &out,
                Match(date: start,
                      timeZone: timeZone,
                      duration: interval,
                      range: r,
                      original: nil,
                      overridden: false,
                      ambiguous: false,
                      ambiguityReason: nil),
                text: text)
        }

        let (thisStart, thisInterval) = weekStartAndInterval(containing: base)
        let nextStart = calendar.date(byAdding: .weekOfYear, value: 1, to: thisStart)!
        let nextInterval = thisInterval

        b.weekMain.enumerateMatches(in: text, options: [], range: full) { m, _, _ in
            guard let m else { return }
            let phrase = ns.substring(with: m.range).lowercased()
            if b.pack.phraseIndicatesNext(phrase) { add(m.range, start: nextStart, interval: nextInterval) }
            else { add(m.range, start: thisStart, interval: thisInterval) }
        }

        b.weekBare.enumerateMatches(in: text, options: [], range: full) { m, _, _ in
            guard let m else { return }
            let already = out.contains { NSIntersectionRange(NSRange($0.range, in: text), m.range).length > 0 }
            if !already { add(m.range, start: thisStart, interval: thisInterval) }
        }
        return out
    }
    
    /// Parse tokens like "9", "9:30", "9am", "9:30pm", "14", "14:15", "10h", "10 hs", "10hrs".
    /// Returns hour/minute in 24h and whether an AM/PM meridiem was present.
    private func parseTimeToken(_ token: String) -> (hour: Int, minute: Int, hadMeridiem: Bool)? {
        // strip spaces and lowercase
        var t = token.replacingOccurrences(of: " ", with: "").lowercased()

        var hadMeridiem = false
        var isPM = false, isAM = false

        if t.hasSuffix("am") {
            hadMeridiem = true; isAM = true; t.removeLast(2)
        } else if t.hasSuffix("pm") {
            hadMeridiem = true; isPM = true; t.removeLast(2)
        } else if t.hasSuffix("hrs") {
            t.removeLast(3) // Portuguese suffix implies 24h clock
        } else if t.hasSuffix("hs") {
            t.removeLast(2)
        } else if t.hasSuffix("h") {
            t.removeLast(1)
        }

        let parts = t.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard let hRaw = parts.first, let h = Int(hRaw), h >= 0, h <= 23 else { return nil }
        let m: Int
        if parts.count == 2 {
            guard let mm = Int(parts[1]), mm >= 0, mm <= 59 else { return nil }
            m = mm
        } else {
            m = 0
        }

        var hour24 = h
        if hadMeridiem {
            if isAM { hour24 = (h == 12) ? 0 : h }
            if isPM { hour24 = (h == 12) ? 12 : h + 12 }
        }
        return (hour24, m, hadMeridiem)
    }

    /// Synthesizes ranges for: "quarta das 9 às 10", "de 14 a 16", "from 9 to 10".
    /// If a weekday is present, anchor to its upcoming occurrence (like "this <weekday>" excl. today).
    /// If no weekday, anchor to `base`'s day; if the range ends before `base`, roll to next day.
    private func fromToTimeMatches(bundle b: PackBundle, in text: String, base: Date) -> [Match] {
        var out: [Match] = []
        let full = NSRange(location: 0, length: (text as NSString).length)

        b.fromTo.enumerateMatches(in: text, options: [], range: full) { m, _, _ in
            guard let m else { return }

            let weekdayStr: String? = (m.range(at: 1).location != NSNotFound) ? substring(text, m.range(at: 1)).lowercased() : nil
            let startTok = substring(text, m.range(at: 2))
            let endTok = substring(text, m.range(at: 3))

            guard var startHM = parseTimeToken(startTok),
                  let endHM0 = parseTimeToken(endTok),
                  let r = Range(m.range, in: text) else { return }
            var endHM = endHM0

            // Anchor day
            let baseStart = calendar.startOfDay(for: base)
            let anchorDay: Date = {
                if let wStr = weekdayStr, let w = b.pack.weekdayMap[wStr] {
                    return calendar.nextDate(after: baseStart, matching: DateComponents(weekday: w), matchingPolicy: .nextTime, direction: .forward)!
                } else {
                    return baseStart
                }
            }()

            alignStart(&startHM, toEndMeridiem: endHM)
            alignEnd(&endHM, toStartMeridiem: startHM)

            var comps = calendar.dateComponents([.year,.month,.day], from: anchorDay)
            comps.second = 0
            comps.hour = startHM.hour; comps.minute = startHM.minute
            guard var startDate = calendar.date(from: comps) else { return }
            comps.hour = endHM.hour; comps.minute = endHM.minute
            guard var endDate = calendar.date(from: comps) else { return }

            if endDate <= startDate && !startHM.hadMeridiem && !endHM.hadMeridiem {
                endDate = calendar.date(byAdding: .hour, value: 12, to: endDate) ?? endDate
            }
            if endDate <= startDate {
                endDate = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
            }
            if weekdayStr == nil && endDate <= base {
                startDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
                endDate   = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
            }

            let dur = endDate.timeIntervalSince(startDate); guard dur > 0 else { return }
            appendUnique(
                &out,
                Match(date: startDate,
                      timeZone: timeZone,
                      duration: dur,
                      range: r,
                      original: nil,
                      overridden: false,
                      ambiguous: false,
                      ambiguityReason: nil),
                text: text)
        }
        return out
    }

    /// Creates synthetic matches for compact patterns like:
    /// "qua 9-10", "quarta 14-16", "fri 9am-10", "ter 10h-12h", and single time "wed 9", "qua 10h".
    private func inlineTimeRangeMatches(bundle: PackBundle, in text: String, base: Date, policy: RelativeWeekdayPolicy) -> [Match] {
        var out: [Match] = []
        let full = NSRange(location: 0, length: (text as NSString).length)
        
        // Trim whitespace and trailing punctuation that often sticks to tokens
        func trimToken(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ",.;:!?"))
        }
        
        bundle.inlineRange.enumerateMatches(in: text, options: [], range: full) { m, _, _ in
            guard let m = m, m.numberOfRanges >= 2 else { return }
            
            // --- Dynamically discover groups ---
            // 1) Find weekday group by consulting the pack's map
            var weekdayIdx: Int?
            var weekdayNum: Int?
            
            for i in 1..<m.numberOfRanges {
                let raw = trimToken(substring(text, m.range(at: i))).lowercased()
                if let w = bundle.pack.weekdayMap[raw] {
                    weekdayIdx = i
                    weekdayNum = w
                    break
                }
            }
            guard let wIdx = weekdayIdx, let weekday = weekdayNum else { return }
            
            // 2) Find start and (optional) end time tokens by parsing remaining groups in order
            var startTok: String?
            var endTok: String?
            
            for i in 1..<m.numberOfRanges where i != wIdx {
                let raw = trimToken(substring(text, m.range(at: i)))
                if raw.isEmpty { continue }
                if parseTimeToken(raw) != nil {
                    if startTok == nil {
                        startTok = raw
                    } else if endTok == nil {
                        endTok = raw
                        break
                    }
                }
            }
            
            guard var startHM = startTok.flatMap(parseTimeToken),
                  let r = Range(m.range, in: text) else { return }
            
            var endHM = endTok.flatMap(parseTimeToken)
            
            // Anchor day: upcoming weekday (exclude today by default)
            let baseStart = calendar.startOfDay(for: base)
            var targetDay = calendar.nextDate(
                after: baseStart,
                matching: DateComponents(weekday: weekday),
                matchingPolicy: .nextTime,
                direction: .forward
            )!
            switch policy.next {
            case .immediateUpcoming:
                break
            case .skipOneWeek:
                targetDay = calendar.date(byAdding: .weekOfYear, value: 1, to: targetDay)!
            }
            
            // If one side has AM/PM and the other doesn't, align to the same half-day
            if let e = endHM {
                alignStart(&startHM, toEndMeridiem: e)
                var e2 = e
                alignEnd(&e2, toStartMeridiem: startHM)
                endHM = e2
            }
            
            // Ambiguity: bare hour(s) without markers (no ":", AM/PM, or h/hs/hrs)
            let startIsBare = isBareHourToken(startTok ?? "")
            let endIsBare   = isBareHourToken(endTok ?? "")
            let ambiguous   = (endTok == nil && startIsBare) || (endTok != nil && startIsBare && !startHM.hadMeridiem)
            let reason      = ambiguous ? "Bare hour without explicit time marker; could be a day number." : nil
            
            // Compose start
            var comps = calendar.dateComponents([.year, .month, .day], from: targetDay)
            comps.hour = startHM.hour
            comps.minute = startHM.minute
            comps.second = 0
            guard let startDate = calendar.date(from: comps) else { return }
            
            if let e = endHM {
                // --- Range case ---
                var endComps = comps
                endComps.hour = e.hour
                endComps.minute = e.minute
                guard var endDate = calendar.date(from: endComps) else { return }
                
                // If end <= start and neither had AM/PM, try +12h (e.g., "11-1" → 11..13)
                if endDate <= startDate && !startHM.hadMeridiem && !e.hadMeridiem {
                    if let bumped = calendar.date(byAdding: .hour, value: 12, to: endDate) {
                        endDate = bumped
                    }
                }
                // If still <= start (rare), push to next day
                if endDate <= startDate {
                    if let bumped = calendar.date(byAdding: .day, value: 1, to: endDate) {
                        endDate = bumped
                    }
                }
                
                let duration = endDate.timeIntervalSince(startDate)
                guard duration > 0 else { return }
                
                out.append(Match(
                    date: startDate,
                    timeZone: timeZone,
                    duration: duration,
                    range: r,
                    original: nil,
                    overridden: false,
                    ambiguous: ambiguous || (endIsBare && !e.hadMeridiem),
                    ambiguityReason: reason
                ))
            } else {
                // --- Single time case ---
                out.append(Match(
                    date: startDate,
                    timeZone: timeZone,
                    duration: policy.defaultSingleDuration,
                    range: r,
                    original: nil,
                    overridden: false,
                    ambiguous: ambiguous,
                    ambiguityReason: reason
                ))
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
    
    private func isBareHourToken(_ token: String) -> Bool {
        let t = token.replacingOccurrences(of: " ", with: "").lowercased()
        // If it has :, am/pm or h/hs/hrs → it’s explicit
        if t.contains(":") || t.hasSuffix("am") || t.hasSuffix("pm") || t.hasSuffix("h") || t.hasSuffix("hs") || t.hasSuffix("hrs") {
            return false
        }
        // Pure 1–2 digit hour 0–23
        if let h = Int(t), (0...23).contains(h) { return true }
        return false
    }
    
    // MARK: - Exact-dedup (don’t collapse alternatives)

    private func dedupExact(_ items: [Match], in text: String) -> [Match] {
        var seen = Set<String>()
        var out: [Match] = []
        out.reserveCapacity(items.count)

        for m in items {
            // Treat provenance as part of the identity: Apple vs Synthetic
//            let provenance = (m.original != nil) ? "apple" : "synthetic"
            let durationKey = m.duration ?? -1
//            let key = "\(nr.location):\(nr.length)|\(m.date.timeIntervalSinceReferenceDate)|\(durationKey)|\(provenance)|\(m.overridden ? 1 : 0)|\(m.ambiguous ? 1 : 0)"
            let key = "\(m.date.timeIntervalSinceReferenceDate)|\(durationKey)|\(m.overridden ? 1 : 0)|\(m.ambiguous ? 1 : 0)"
            if seen.insert(key).inserted {
                out.append(m)
            }
        }
        return out
    }
    
    /// If end has meridiem but start doesn't, align start to end's half-day (AM/PM).
    private func alignStart(_ start: inout (hour: Int, minute: Int, hadMeridiem: Bool),
                            toEndMeridiem end: (hour: Int, minute: Int, hadMeridiem: Bool)) {
        guard end.hadMeridiem, !start.hadMeridiem else { return }
        // Treat AM as <12, PM as >=12
        let endIsPM = end.hour >= 12
        if endIsPM, start.hour < 12 { start.hour += 12 }
        if !endIsPM, start.hour >= 12 { start.hour -= 12 } // defensive; rarely needed
    }

    /// If start has meridiem but end doesn't, align end to start's half-day (AM/PM).
    private func alignEnd(_ end: inout (hour: Int, minute: Int, hadMeridiem: Bool),
                          toStartMeridiem start: (hour: Int, minute: Int, hadMeridiem: Bool)) {
        guard start.hadMeridiem, !end.hadMeridiem else { return }
        let startIsPM = start.hour >= 12
        if startIsPM, end.hour < 12 { end.hour += 12 }
        if !startIsPM, end.hour >= 12 { end.hour -= 12 }
    }
}
