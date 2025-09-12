
import Foundation

// MARK: - Public API

public enum Intent { case create, reschedule, cancel, view, plan, unknown }

public struct Preferences {
    public var timeZone: TimeZone = TimeZone(identifier: "America/Sao_Paulo")!
    public var startOfWeek: Int = 2 // Monday
    public var anchors: [PartOfDay: DateComponents] = [
        .morning: .init(hour: 9),
        .afternoon: .init(hour: 15),
        .evening: .init(hour: 19),
        .night: .init(hour: 20),
        .noon: .init(hour: 12),
        .midnight: .init(hour: 0),
    ]
    public var nextWeekPolicyCalendarWeek: Bool = true
    public var weekendAnchorHour: Int = 10 // For create/reschedule when only "weekend" is given
    public init() {}
}

public struct TemporalToken {
    public let range: NSRange
    public let text: String
    public enum Kind {
        case absoluteDate(DateComponents)
        case absoluteTime(DateComponents)
        case timeRange(start: DateComponents, end: DateComponents)
        case weekday(dayIndex: Int, modifier: WeekModifier?)
        case relativeDay(RelativeDay)
        case relativeWeek(WeekSpecifier)
        case weekend(WeekSpecifier?) // nil when bare
        case partOfDay(PartOfDay)
        case ordinalDay(Int)
        case durationOffset(value: Int, unit: Calendar.Component, mode: OffsetMode)
        case connector
    }
    public let kind: Kind
    
    public func tokenPriority() -> Int {
        switch kind {
        case .timeRange:                 return 90
        case .absoluteTime:              return 80
        case .weekday:                   return 75
        case .relativeWeek:              return 74
        case .relativeDay:               return 73
        case .weekend:                   return 72
        case .partOfDay:                 return 70
        case .ordinalDay:                return 60
        case .durationOffset:            return 40
        case .absoluteDate:              return 10   // <- softest
        case .connector:                 return 5
        }
    }
}

public enum ResolvedTemporal {
    case instant(Date, confidence: Double, notes: [String], duration: TimeInterval? = nil)
    case range(DateInterval, confidence: Double, notes: [String])
}

public struct ParseResult {
    public let title: String
    public let intent: Intent
    public let resolution: ResolvedTemporal?
    public let filters: [ResolvedTemporal]
    public let ignoredNotes: [String]
}

// MARK: - Composer

public final class TemporalComposer {
    private let pack: DateLanguagePack
    private var prefs: Preferences
    private var calendar: Calendar

    public init(pack: DateLanguagePack, prefs: Preferences = Preferences()) {
        self.pack = pack
        self.prefs = prefs
        var cal = pack.calendar
        cal.timeZone = prefs.timeZone
        cal.firstWeekday = prefs.startOfWeek
        self.calendar = cal
    }

    // Entry point
    public func parse(_ text: String, now: Date, originalEvent: Date? = nil) -> ParseResult {
        let (clean, title, intent) = preprocess(text)
        let tokens = detectTokens(in: clean, now: now)
//        let (resolution, filters, ignored) = compose(tokens: tokens, text: clean, intent: intent, now: now, originalEvent: originalEvent)
        let interpreter = TemporalTokenInterpreter(calendar: calendar, timeZone: calendar.timeZone, referenceDate: now)
        let context = interpreter.interpret(tokens)
        
        var resolution: ResolvedTemporal
        var filters: [ResolvedTemporal] = []
        if context.isRangeQuery, let dateInterval = context.dateRange {
            resolution = .range(dateInterval, confidence: Double(context.confidence), notes: context.conflicts)
            filters.append(resolution)
        } else {
            resolution = .instant(context.finalDate, confidence: Double(context.confidence), notes: context.conflicts, duration: context.finalDateDuration)
        }
        
        return ParseResult(title: title, intent: intent, resolution: resolution, filters: filters, ignoredNotes: [])
    }

    // MARK: - Preprocess

    private func preprocess(_ s: String) -> (clean: String, title: String, intent: Intent) {
        let intent = detectIntent(s)
        let prefixRe = pack.commandPrefixRegex()
        let ns = s as NSString
        var clean = s
        if let m = prefixRe.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) {
            let r = m.range
            if r.location == 0 {
                clean = ns.substring(from: r.length).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // Strip leading connectors in title only (e.g., "at", "on")
        var title = clean
        if let firstWord = clean.split(separator: " ").first {
            let lw = firstWord.lowercased()
            if pack.connectorTokens.contains(lw) {
                title = String(clean.dropFirst(firstWord.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return (clean, title, intent)
    }

    private func detectIntent(_ s: String) -> Intent {
        let range = NSRange(location: 0, length: (s as NSString).length)
        if pack.intentRescheduleRegex().firstMatch(in: s, options: [], range: range) != nil { return .reschedule }
        if pack.intentCancelRegex().firstMatch(in: s, options: [], range: range) != nil { return .cancel }
        if pack.intentViewRegex().firstMatch(in: s, options: [], range: range) != nil { return .view }
        if pack.intentPlanRegex().firstMatch(in: s, options: [], range: range) != nil { return .plan }
        if pack.intentCreateRegex().firstMatch(in: s, options: [], range: range) != nil { return .create }
        return .unknown
    }

    // MARK: - Detection

    private func detectTokens(in text: String, now: Date) -> [TemporalToken] {
        var tokens: [TemporalToken] = []

        func add(_ re: NSRegularExpression?, _ make: (NSTextCheckingResult, String) -> TemporalToken?) {
            guard let re = re else { return }
            let ns = text as NSString
            re.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) { m, _, _ in
                guard let m = m else { return }
                let sub = ns.substring(with: m.range)
                if let t = make(m, sub) { tokens.append(t) }
            }
        }

        // Weekday + optional modifier
        add(pack.weekdayPhraseRegex()) { m, _ in
            let fullNS = text as NSString
            let modR = m.range(at: 1)
            var modifier: WeekModifier? = nil
            if modR.location != NSNotFound && modR.length > 0 {
                let mod = fullNS.substring(with: modR).lowercased()
                if pack.thisTokens.contains(where: { mod.contains($0.lowercased()) }) { modifier = .this }
                if pack.nextTokens.contains(where: { mod.contains($0.lowercased()) }) { modifier = .next }
            }
            let wdR = m.range(at: m.numberOfRanges - 1)
            let wdToken = fullNS.substring(with: wdR)
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: pack.calendar.locale ?? .current)
                .lowercased()
                .replacingOccurrences(of: ".", with: "")
            if let idx = pack.weekdayMap[wdToken] {
                return TemporalToken(range: m.range, text: fullNS.substring(with: m.range), kind: .weekday(dayIndex: idx, modifier: modifier))
            }
            return nil
        }

        // Week phrases
        add(pack.weekMainRegex()) { m, sub in
            let count = pack.nextRepetitionCount(in: sub)
            return TemporalToken(range: m.range, text: sub, kind: count > 0 ? .relativeWeek(.nextWeek(count: count)) : .relativeWeek(.thisWeek))
        }

        // Bare week cues
        add(pack.weekBareRegex()) { m, sub in TemporalToken(range: m.range, text: sub, kind: .relativeWeek(.thisWeek)) }

        // Weekend
        add(pack.weekendRegex()) { m, sub in
            let spec: WeekSpecifier? = pack.phraseIndicatesNext(sub) ? .nextWeek(count: 1) : .thisWeek
            return TemporalToken(range: m.range, text: sub, kind: .weekend(spec))
        }

        // Relative day
        add(pack.relativeDayRegex()) { m, sub in
            let l = sub.lowercased()
            if let rd = pack.classifyRelativeDay(l) {
                return TemporalToken(range: m.range, text: sub, kind: .relativeDay(rd))
            }
            return nil
        }

        // Part of day
        add(pack.partOfDayRegex()) { m, sub in
            let l = sub.lowercased()
            if let p = pack.classifyPartOfDay(l) {
                return TemporalToken(range: m.range, text: sub, kind: .partOfDay(p))
            }
            return nil
        }

        add(pack.ordinalDayRegex()) { m, sub in
            let nsAll = text as NSString
            var day: Int?
            // Try to find the first numeric capture among groups 1..N
            for i in 1..<m.numberOfRanges {
                let r = m.range(at: i)
                guard r.location != NSNotFound, r.length > 0 else { continue }
                let raw = nsAll.substring(with: r)
                // Extract digits robustly (handles "24th", "24º", "dia 24", etc.)
                let digits = raw.replacingOccurrences(of: #"[^\d]"#, with: "", options: .regularExpression)
                if let d = Int(digits) { day = d; break }
            }

            if let d = day {
                return TemporalToken(range: m.range, text: sub, kind: .ordinalDay(d))
            }
            return nil
        }

        // Inline weekday + time[-time] (robust)
        add(pack.inlineTimeRangeRegex()) { m, _ in
            let nsAll = text as NSString

            // Collect candidates from captured groups (skip group 0 = whole match)
            var weekdayHit: (idx: Int, range: NSRange, text: String)?
            var timeHits: [(range: NSRange, text: String, comps: DateComponents)] = []

            for i in 1..<m.numberOfRanges {
                let r = m.range(at: i)
                if r.location == NSNotFound || r.length == 0 { continue }
                let raw = nsAll.substring(with: r)

                // Normalize for weekday lookup
                let norm = raw
                    .folding(options: [.diacriticInsensitive, .caseInsensitive],
                             locale: pack.calendar.locale ?? .current)
                    .lowercased()
                    .replacingOccurrences(of: ".", with: "")

                // First, try weekday
                if weekdayHit == nil, let idx = pack.weekdayMap[norm] {
                    weekdayHit = (idx, r, raw)
                    continue
                }

                // Then, try time
                if let comps = parseTime(raw) {
                    timeHits.append((r, raw, comps))
                    continue
                }
            }

            // Emit time tokens based on what we found (prefer explicit hits)
            if let first = timeHits.first {
                if timeHits.count >= 2 {
                    let second = timeHits[1]
                    tokens.append(
                        TemporalToken(
                            range: NSUnionRange(first.range, second.range),
                            text: first.text + "–" + second.text,
                            kind: .timeRange(start: first.comps, end: second.comps)
                        )
                    )
                } else {
                    tokens.append(TemporalToken(range: first.range, text: first.text, kind: .absoluteTime(first.comps)))
                }
            }

            // Return the weekday token (so `add(...)` appends it), if found
            if let wd = weekdayHit {
                return TemporalToken(range: wd.range, text: wd.text, kind: .weekday(dayIndex: wd.idx, modifier: nil))
            }
            return nil
        }


        // from-to
        add(pack.fromToTimeRegex()) { m, sub in
            let nsAll = text as NSString
            let wdRange = m.range(at: 1)
            if wdRange.location != NSNotFound {
                let wdText = nsAll.substring(with: wdRange).lowercased().folding(options: [.diacriticInsensitive, .caseInsensitive], locale: pack.calendar.locale ?? .current)
                if let idx = pack.weekdayMap[wdText] {
                    tokens.append(TemporalToken(range: wdRange, text: nsAll.substring(with: wdRange), kind: .weekday(dayIndex: idx, modifier: nil)))
                }
            }
            let sText = nsAll.substring(with: m.range(at: 2))
            let eText = nsAll.substring(with: m.range(at: 3))
            if let sComp = parseTime(sText), let eComp = parseTime(eText) {
                return TemporalToken(range: m.range, text: sub, kind: .timeRange(start: sComp, end: eComp))
            }
            return nil
        }

        // between
        add(pack.betweenTimeRegex()) { m, sub in
            let nsAll = text as NSString
            let sText = nsAll.substring(with: m.range(at: 1))
            let eText = nsAll.substring(with: m.range(at: 2))
            if let sComp = parseTime(sText), let eComp = parseTime(eText) {
                return TemporalToken(range: m.range, text: sub, kind: .timeRange(start: sComp, end: eComp))
            }
            return nil
        }

        // time-only
        add(pack.timeOnlyRegex()) { m, sub in
            if let comps = parseTime(sub) {
                return TemporalToken(range: m.range, text: sub, kind: .absoluteTime(comps))
            }
            return nil
        }

        // durations
        func unitFrom(_ s: String) -> Calendar.Component? {
            let l = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: pack.calendar.locale ?? .current)
            if l.hasPrefix("min") { return .minute }
            if l.hasPrefix("hour") || l.hasPrefix("hr") || l == "h" || l.hasPrefix("hora") { return .hour }
            if l.hasPrefix("day") || l.hasPrefix("dia") { return .day }
            if l.hasPrefix("week") || l.hasPrefix("semana") { return .weekOfYear }
            if l.hasPrefix("month") || l.hasPrefix("mes") { return .month }
            return nil
        }
        add(pack.inFromNowRegex()) { m, sub in
            let nsAll = text as NSString
            if m.numberOfRanges >= 3 {
                let val = Int(nsAll.substring(with: m.range(at: 1))) ?? 0
                let unitS = nsAll.substring(with: m.range(at: 2))
                if let unit = unitFrom(unitS) {
                    return TemporalToken(range: m.range, text: sub, kind: .durationOffset(value: val, unit: unit, mode: .fromNow))
                }
            }
            return nil
        }
        add(pack.byOffsetRegex()) { m, sub in
            let nsAll = text as NSString
            if m.numberOfRanges >= 3 {
                let val = Int(nsAll.substring(with: m.range(at: 1))) ?? 0
                let unitS = nsAll.substring(with: m.range(at: 2))
                if let unit = unitFrom(unitS) {
                    return TemporalToken(range: m.range, text: sub, kind: .durationOffset(value: val, unit: unit, mode: .shift))
                }
            }
            return nil
        }

        // 2) NSDataDetector fallback — classify time-only correctly using language pack
        func hasRelativeCues(_ s: String) -> Bool {
            let range = NSRange(location: 0, length: (s as NSString).length)
            if pack.weekdayPhraseRegex().firstMatch(in: s, options: [], range: range) != nil { return true }
            if pack.weekMainRegex().firstMatch(in: s, options: [], range: range) != nil { return true }
            if let r = pack.relativeDayRegex(), r.firstMatch(in: s, options: [], range: range) != nil { return true }
            if let r = pack.partOfDayRegex(), r.firstMatch(in: s, options: [], range: range) != nil { return true }
            return false
        }

        if let dd = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let ns = text as NSString
            dd.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) { m, _, _ in
                guard let m = m, let date = m.date else { return }
                let substr = ns.substring(with: m.range)
                if let tre = pack.timeOnlyRegex() {
                    let full = NSRange(location: 0, length: (substr as NSString).length)
                    if let mm = tre.firstMatch(in: substr, options: [], range: full), mm.range.length == full.length {
                        if let comps = parseTime(substr) {
                            tokens.append(TemporalToken(range: m.range, text: substr, kind: .absoluteTime(comps)))
                            return
                        }
                    }
                }
                if hasRelativeCues(substr) { return }
                let comps = Calendar.current.dateComponents(in: prefs.timeZone, from: date)
                tokens.append(TemporalToken(range: m.range, text: substr, kind: .absoluteDate(comps)))
            }
        }

        // Try to interpret the tokens
//        tokens = reconcileByContext(tokens: tokens)

        // Dedupe longest-span-wins
        tokens.sort {
            if $0.range.location != $1.range.location { return $0.range.location < $1.range.location }
            if $0.tokenPriority() != $1.tokenPriority() { return $0.tokenPriority() > $1.tokenPriority() }
            return $0.range.length > $1.range.length
        }
        var kept: [TemporalToken] = []
        for t in tokens {
            // Only suppress if a higher/equal priority token fully covers this one.
            if !kept.contains(where: {
                NSIntersectionRange($0.range, t.range).length == t.range.length
                && $0.tokenPriority() >= t.tokenPriority()
            }) {
                kept.append(t)
            }
        }
        return kept
    }

    // MARK: - Compose

    private struct DayScope {
        enum Kind { case absolute(DateComponents), relativeDay(RelativeDay), week(WeekSpecifier), weekend(WeekSpecifier?), weekday(dayIndex: Int, modifier: WeekModifier?), ordinalDay(Int) }
        let kind: Kind
    }

    private func compose(tokens: [TemporalToken], text: String, intent: Intent, now: Date, originalEvent: Date?) -> (ResolvedTemporal?, [ResolvedTemporal], [String]) {
        var ignored: [String] = []

        let scope = resolveDayScope(tokens: tokens, intent: intent, now: now)
        let time = resolveTime(tokens: tokens, text: text, scope: scope, now: now, ignored: &ignored)

        if intent == .view || intent == .plan {
            if let interval = rangeForScope(scope: scope, now: now) {
                return (.range(interval, confidence: 0.9, notes: []), [.range(interval, confidence: 0.9, notes: [])], ignored)
            }
            let part = tokens.compactMap { t -> PartOfDay? in if case .partOfDay(let p) = t.kind { return p } else { return nil } }.last
            if let dayDate = buildDate(scope: scope, time: nil, now: now) {
                let dayStart = calendar.startOfDay(for: dayDate)
                let slice = dayInterval(for: dayStart, part: part)
                return (.range(slice, confidence: 0.9, notes: []), [.range(slice, confidence: 0.9, notes: [])], ignored)
            }
        }

        if let date = buildDate(scope: scope, time: time, now: now) {
            return (.instant(date, confidence: 0.95, notes: []), [], ignored)
        }
        if let interval = rangeForScope(scope: scope, now: now) {
            let anchor = anchorForRange(interval: interval, scope: scope)
            return (.instant(anchor, confidence: 0.75, notes: ["Anchored inside range"]), [], ignored)
        }
        return (nil, [], ignored)
    }
    
    // MARK: - Token reconciliation (context-aware, no substring checks)

    /// Rewrites/removes tokens that are artifacts of NSDataDetector when they conflict
    /// with higher-level semantics expressed by other tokens.
    /// * No regex on substrings, only relationships between tokens.
    private func reconcileByContext(tokens toks: [TemporalToken]) -> [TemporalToken] {
        // Gather context
        let hasRelativeWeek = toks.contains {
            if case .relativeWeek = $0.kind { return true }
            return false
        }
        let hasWeekend = toks.contains {
            if case .weekend = $0.kind { return true }
            return false
        }

        // Index useful subsets
        let weekdayTokens = toks.compactMap { t -> (NSRange, Int)? in
            if case .weekday(let idx, _) = t.kind { return (t.range, idx) }
            return nil
        }

        let timeTokens = toks.filter {
            switch $0.kind {
            case .absoluteTime, .timeRange: return true
            default: return false
            }
        }

        // Helper: does a token overlap any weekday token?
        func overlapsWeekday(_ r: NSRange) -> Bool {
            weekdayTokens.contains(where: { NSIntersectionRange($0.0, r).length > 0 })
        }

        // Helper: does a token overlap any time token?
        func overlapsTime(_ r: NSRange) -> Bool {
            timeTokens.contains(where: { NSIntersectionRange($0.range, r).length > 0 })
        }

        // Start rewriting
        var out: [TemporalToken] = []
        out.reserveCapacity(toks.count)

        for t in toks {
            switch t.kind {
            case .absoluteDate:
                // If the utterance has a week cue (this/next week or weekend)
                // AND this absoluteDate came from a "weekday(+time)" style phrase
                // (identified purely by overlap with a .weekday token),
                // then treat it as an NSDataDetector artifact and neutralize it so
                // the composer will use (relativeWeek + weekday [+ time]) correctly.
                if (hasRelativeWeek || hasWeekend) && overlapsWeekday(t.range) {
                    // If there's already a separate time token overlapping, just drop this DD date.
                    if overlapsTime(t.range) {
                        continue // drop
                    }
                    // No overlapping time token (likely plain "Fri" without time).
                    // Drop it as well — the week+weekday scope will drive the date and
                    // the composer will anchor the time (9:00) or use part-of-day if present.
                    continue
                }
                out.append(t)

            default:
                out.append(t)
            }
        }

        return out
    }


    // MARK: - Day scope resolution (intent-aware + combinators)

    private func resolveDayScope(tokens: [TemporalToken], intent: Intent, now: Date) -> DayScope? {
        // Helpers
        func first<T>(_ f: (TemporalToken.Kind) -> T?) -> T? {
            for t in tokens {
                if let v = f(t.kind) { return v }
            }
            return nil
        }

        // 1) COMBINE: relativeWeek + weekday  → weekday with modifier (this/next)
        //    Example: “next week Fri 11:00” should resolve to Friday of next week.
        let combinedWeekday: DayScope? = {
            var relSpec: WeekSpecifier?
            var wd: (idx: Int, mod: WeekModifier?)?

            for t in tokens {
                switch t.kind {
                case .relativeWeek(let spec): relSpec = spec
                case .weekday(let idx, let mod): wd = (idx, mod)
                default: break
                }
            }
            if let spec = relSpec, let wd = wd {
                // Prefer explicit weekday; apply modifier from week spec
                let forcedMod: WeekModifier = (spec == .thisWeek) ? .this : .next
                return DayScope(kind: .weekday(dayIndex: wd.idx, modifier: forcedMod))
            }
            return nil
        }()

        if let combined = combinedWeekday {
            return combined
        }

        // 2) Extract single-token candidates
        let weekScope: DayScope? = first { if case .relativeWeek(let s) = $0 { return DayScope(kind: .week(s)) } else { return nil } }
        let weekendScope: DayScope? = first { if case .weekend(let s) = $0 { return DayScope(kind: .weekend(s)) } else { return nil } }
        let relDayScope: DayScope? = first { if case .relativeDay(let r) = $0 { return DayScope(kind: .relativeDay(r)) } else { return nil } }
        let weekdayScope: DayScope? = first { if case .weekday(let i, let m) = $0 { return DayScope(kind: .weekday(dayIndex: i, modifier: m)) } else { return nil } }
        let ordinalScope: DayScope? = first { if case .ordinalDay(let d) = $0 { return DayScope(kind: .ordinalDay(d)) } else { return nil } }
        let absoluteScope: DayScope? = first { if case .absoluteDate(let c) = $0 { return DayScope(kind: .absolute(c)) } else { return nil } }

        // 3) Intent-driven priority
        switch intent {
        case .create, .reschedule, .cancel:
            // For “do something at a specific time”, prefer the most concrete day signal.
            return absoluteScope
                ?? weekdayScope
                ?? relDayScope
                ?? weekScope
                ?? weekendScope
                ?? ordinalScope

        case .view, .plan:
            // For agenda/plan, prefer ranges first, but still use concrete day if present.
            return weekScope
                ?? weekendScope
                ?? relDayScope
                ?? weekdayScope
                ?? ordinalScope
                ?? absoluteScope

        case .unknown:
            // Balanced default
            return absoluteScope
                ?? weekdayScope
                ?? relDayScope
                ?? weekScope
                ?? weekendScope
                ?? ordinalScope
        }
    }

    // Time parsing helper
    func parseTime(_ s: String) -> DateComponents? {
        let lower = s.lowercased().trimmingCharacters(in: .whitespaces)
        if let p = pack.classifyPartOfDay(lower) {
            switch p {
            case .noon: return DateComponents(hour: 12, minute: 0)
            case .midnight: return DateComponents(hour: 0, minute: 0)
            default: break
            }
        }
        let re = BaseLanguagePack.regex(#"""
            (?ix) ^ \s*
            (?:(?<h>[01]?\d|2[0-3]))
            (?:
                :(?<m>\d{2})
              | \s*[hH]\s*(?<mh>\d{2})?
            )?
            \s*(?<ampm>am|pm)?
            \s*(?:hs?|hrs?)?
            \s* $
        """#)
        
        if let m = re.firstMatch(in: lower, range: NSRange(location: 0, length: (lower as NSString).length)) {
            func grp(_ name: String) -> String? {
                let r = m.range(withName: name)
                if r.location != NSNotFound { return (lower as NSString).substring(with: r) }
                return nil
            }
            if let hs = grp("h"), let h = Int(hs) {
                var hour = h
                var minute = 0
                if let ms = grp("m"), let mm = Int(ms) { minute = mm }
                else if let ms = grp("mh"), let mm = Int(ms) { minute = mm }
                if let ap = grp("ampm") {
                    if ap == "pm" { if hour < 12 { hour += 12 } }
                    if ap == "am" { if hour == 12 { hour = 0 } }
                }
                return DateComponents(hour: hour, minute: minute)
            }
        }
        return nil
    }

    private func resolveTime(tokens: [TemporalToken], text: String, scope: DayScope?, now: Date, ignored: inout [String]) -> DateComponents? {
        if let tr = tokens.last(where: { if case .timeRange = $0.kind { return true } else { return false } }),
           case .timeRange(let s, _) = tr.kind { return s }

        let ns = text as NSString
        let pivotRe = pack.timePivotRegex()
        var pivot = NSNotFound
        pivotRe.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            if let m = m { pivot = max(pivot, m.range.location + m.range.length) }
        }

        let absolutes = tokens.filter { if case .absoluteTime = $0.kind { return true } else { return false } }
        if !absolutes.isEmpty {
            var candidate = absolutes.last!
            if pivot != NSNotFound {
                if let right = absolutes.filter({ $0.range.location >= pivot }).last {
                    candidate = right
                    for t in absolutes where t.range.location < right.range.location {
                        ignored.append("Ignored earlier time “\(t.text)”")
                    }
                }
            }
            if case .absoluteTime(let comps) = candidate.kind { return comps }
        }

        if let pod = tokens.last(where: { if case .partOfDay = $0.kind { return true } else { return false } }),
           case .partOfDay(let p) = pod.kind {
            return prefs.anchors[p] ?? DateComponents(hour: 9, minute: 0)
        }

        if let s = scope, case .relativeDay(let rd) = s.kind, rd == .tonight {
            return prefs.anchors[.night] ?? DateComponents(hour: 20)
        }
        return nil
    }

    private func rangeForScope(scope: DayScope?, now: Date) -> DateInterval? {
        guard let scope = scope else { return nil }
        switch scope.kind {
        case .week(let spec):
            let start = startOfISOWeek(for: now)
            let weeks = (spec == .thisWeek) ? 0 : specNextCount(spec)
            let s = calendar.date(byAdding: .weekOfYear, value: weeks, to: start)!
            let e = calendar.date(byAdding: .day, value: 7, to: s)!
            return DateInterval(start: s, end: e)
        case .weekend(let spec):
            let baseStart: Date
            if let spec = spec {
                let weekRange = rangeForScope(scope: .init(kind: .week(spec)), now: now)!
                baseStart = weekRange.start
            } else {
                baseStart = startOfISOWeek(for: now)
            }
            let sat = weekdayDate(from: baseStart, weekday: 7)
            let end = calendar.date(byAdding: .day, value: 2, to: sat)!
            return DateInterval(start: sat, end: end)
        default: return nil
        }
    }

    private func anchorForRange(interval: DateInterval, scope: DayScope?) -> Date {
        if case .weekend = scope?.kind {
            return calendar.date(bySettingHour: prefs.weekendAnchorHour, minute: 0, second: 0, of: interval.start)!
        }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: interval.start)!
    }

    private func buildDate(scope: DayScope?, time: DateComponents?, now: Date) -> Date? {
        var dayDate: Date?
        if let scope = scope {
            switch scope.kind {
            case .absolute(let comps):
                dayDate = calendar.date(from: comps)
            case .relativeDay(let rd):
                let delta = (rd == .tomorrow) ? 1 : 0
                dayDate = calendar.date(byAdding: .day, value: delta, to: calendar.startOfDay(for: now))
            case .week(let spec):
                let wd = prefs.startOfWeek // if no weekday, use Monday
                dayDate = date(for: spec, weekday: wd, now: now)
            case .weekend:
                let interval = rangeForScope(scope: scope, now: now)!
                dayDate = interval.start
            case .weekday(let idx, let mod):
                dayDate = dateForWeekday(idx, modifier: mod, now: now)
            case .ordinalDay(let d):
                dayDate = dateForOrdinal(d, now: now)
            }
        } else {
            dayDate = calendar.startOfDay(for: now)
        }
        guard let baseDay = dayDate else { return nil }
        var date = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: baseDay)!
        if let t = time {
            date = calendar.date(bySettingHour: t.hour ?? 9, minute: t.minute ?? 0, second: 0, of: baseDay)!
        } else if case .weekend = scope?.kind {
            date = calendar.date(bySettingHour: prefs.weekendAnchorHour, minute: 0, second: 0, of: baseDay)!
        }
        return date
    }
    
    /// Returns true if the phrase itself contains relative cues that we should compose.
    private func hasRelativeCues(_ s: String) -> Bool {
        let range = NSRange(location: 0, length: (s as NSString).length)
        if pack.weekdayPhraseRegex().firstMatch(in: s, options: [], range: range) != nil { return true }
        if pack.weekMainRegex().firstMatch(in: s, options: [], range: range) != nil { return true }
        if let r = pack.relativeDayRegex(), r.firstMatch(in: s, options: [], range: range) != nil { return true }
        if let r = pack.partOfDayRegex(), r.firstMatch(in: s, options: [], range: range) != nil { return true }
        return false
    }

    private func dayInterval(for day: Date, part: PartOfDay?) -> DateInterval {
        func H(_ h: Int, _ m: Int = 0) -> Date { calendar.date(bySettingHour: h, minute: m, second: 0, of: day)! }
        switch part {
        case .some(.morning):   return DateInterval(start: H(8),  end: H(12))
        case .some(.afternoon): return DateInterval(start: H(12), end: H(18))
        case .some(.evening):   return DateInterval(start: H(18), end: H(22))
        case .some(.night):   return DateInterval(start: H(20), end: H(23,59))
        case .some(.noon):      return DateInterval(start: H(12), end: H(13))
        case .some(.midnight):  return DateInterval(start: H(0),  end: H(1))
        case .none:             return DateInterval(start: H(0),  end: H(23,59))
        }
    }

    // MARK: - Calendar helpers

    private func startOfISOWeek(for d: Date) -> Date {
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
        comps.weekday = prefs.startOfWeek
        return calendar.date(from: comps)!
    }

    private func specNextCount(_ s: WeekSpecifier) -> Int {
        switch s {
        case .thisWeek: return 0
        case .nextWeek(let count): return max(1, count)
        case .lastWeek(count: let count):  return max(1, count)
        }
    }

    private func weekdayDate(from weekStart: Date, weekday: Int) -> Date {
        let offset = (weekday - prefs.startOfWeek + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: weekStart)!
    }

    private func date(for spec: WeekSpecifier, weekday: Int, now: Date) -> Date {
        let base = startOfISOWeek(for: now)
        let weeks = specNextCount(spec)
        let weekStart = calendar.date(byAdding: .weekOfYear, value: weeks, to: base)!
        return weekdayDate(from: weekStart, weekday: weekday)
    }

    private func dateForWeekday(_ idx: Int, modifier: WeekModifier?, now: Date) -> Date {
        let today = now
        let todayW = calendar.component(.weekday, from: today)
        let baseStart = startOfISOWeek(for: today)
        let useNextWeek: Bool = {
            if let mod = modifier {
                return mod == .next
            } else {
                let offset = (idx - todayW + 7) % 7
                return offset == 0 // if today, pick next week's same weekday for bare names
            }
        }()
        if useNextWeek && prefs.nextWeekPolicyCalendarWeek {
            let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: baseStart)!
            return weekdayDate(from: nextWeekStart, weekday: idx)
        }
        let offset = (idx - todayW + 7) % 7
        let days = (offset == 0) ? 7 : offset
        return calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: today))!
    }

    private func dateForOrdinal(_ day: Int, now: Date) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        if day < (comps.day ?? 1) {
            if let next = calendar.date(byAdding: .month, value: 1, to: now) {
                comps = calendar.dateComponents([.year, .month], from: next)
            }
        }
        comps.day = day
        return calendar.date(from: comps)!
    }
}
