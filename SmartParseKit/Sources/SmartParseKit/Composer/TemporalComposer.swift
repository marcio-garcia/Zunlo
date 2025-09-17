
import Foundation

// MARK: - Public API

public struct Preferences {
    public var calendar: Calendar
    public var startOfWeek: Int
    public var anchors: [PartOfDay: DateComponents]
    public var nextWeekPolicyCalendarWeek: Bool
    public var weekendAnchorHour: Int
    
    public init(
        calendar: Calendar = .current,
        startOfWeek: Int = 2, // Monday
        anchors: [PartOfDay : DateComponents] = [
            .morning: .init(hour: 9),
            .afternoon: .init(hour: 15),
            .evening: .init(hour: 19),
            .night: .init(hour: 20),
            .noon: .init(hour: 12),
            .midnight: .init(hour: 0),],
        nextWeekPolicyCalendarWeek: Bool = true,
        weekendAnchorHour: Int = 10 // For create/reschedule when only "weekend" is given
    ) {
        self.calendar = calendar
        self.startOfWeek = startOfWeek
        self.anchors = anchors
        self.nextWeekPolicyCalendarWeek = nextWeekPolicyCalendarWeek
        self.weekendAnchorHour = weekendAnchorHour
    }

}

public struct TemporalToken: Equatable {
    public let range: NSRange
    public let text: String
    public enum Kind: Equatable {
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
    
    public init(range: NSRange, text: String, kind: TemporalToken.Kind) {
        self.range = range
        self.text = text
        self.kind = kind
    }
}

public enum ResolvedTemporal {
    case instant(Date, confidence: Double, notes: [String], duration: TimeInterval? = nil)
    case range(DateInterval, confidence: Double, notes: [String])
}

public protocol InputParser {
    func parse(_ text: String, now: Date, pack: DateLanguagePack, intentDetector: IntentDetector) -> (Intent, [TemporalToken], MetadataExtractionResult)
}

// MARK: - Composer

public final class TemporalComposer: InputParser {
    private var prefs: Preferences
    private var calendar: Calendar

    public init(prefs: Preferences = Preferences()) {
        self.prefs = prefs
        self.calendar = prefs.calendar
        self.calendar.firstWeekday = prefs.startOfWeek
    }

    // Entry point
    public func parse(_ text: String, now: Date, pack: DateLanguagePack, intentDetector: IntentDetector) -> (Intent, [TemporalToken], MetadataExtractionResult) {
        let temporalTokens = detectTokens(in: text, now: now, pack: pack)

        // Extract metadata using the new MetadataExtractor
        let metadataResult = MetadataExtractor().extractMetadata(
            from: text,
            temporalRanges: temporalTokens.compactMap({ Range($0.range, in: text) }),
            pack: pack
        )

        // Use new intent interpreter for classification
        let intentInterpreter = IntentInterpreter()
        let intentAmbiguity = intentInterpreter.classify(inputText: text, metadataTokens: metadataResult.tokens, temporalTokens: temporalTokens, languagePack: pack)

        // Create enhanced metadata result with intent ambiguity
        let enhancedMetadataResult = MetadataExtractionResult(
            tokens: metadataResult.tokens,
            title: metadataResult.title,
            confidence: metadataResult.confidence,
            conflicts: metadataResult.conflicts,
            intentAmbiguity: intentAmbiguity.isAmbiguous ? intentAmbiguity : nil
        )

        return (intentAmbiguity.primaryIntent, temporalTokens, enhancedMetadataResult)
    }

    // MARK: - Detection

    private func detectTokens(in text: String, now: Date, pack: DateLanguagePack) -> [TemporalToken] {
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
            var rawTimeTexts: [String] = [] // Keep track of original text for AM/PM analysis
            
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
                if let comps = parseTime(raw, pack: pack) {
                    timeHits.append((r, raw, comps))
                    rawTimeTexts.append(raw) // Store original text
                    continue
                }
            }
            
            // Emit time tokens based on what we found
            if let first = timeHits.first {
                if timeHits.count >= 2 {
                    let second = timeHits[1]
                    
                    // Use improved time range parsing
                    if let (adjustedFirst, adjustedSecond) = parseTimeRange(rawTimeTexts[0], rawTimeTexts[1], pack: pack) {
                        tokens.append(
                            TemporalToken(
                                range: NSUnionRange(first.range, second.range),
                                text: first.text + "-" + second.text,
                                kind: .timeRange(start: adjustedFirst, end: adjustedSecond)
                            )
                        )
                    } else {
                        // Fallback to original logic
                        tokens.append(
                            TemporalToken(
                                range: NSUnionRange(first.range, second.range),
                                text: first.text + "-" + second.text,
                                kind: .timeRange(start: first.comps, end: second.comps)
                            )
                        )
                    }
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
            if let sComp = parseTime(sText, pack: pack), let eComp = parseTime(eText, pack: pack) {
                return TemporalToken(range: m.range, text: sub, kind: .timeRange(start: sComp, end: eComp))
            }
            return nil
        }

        // between
        add(pack.betweenTimeRegex()) { m, sub in
            let nsAll = text as NSString
            let sText = nsAll.substring(with: m.range(at: 1))
            let eText = nsAll.substring(with: m.range(at: 2))
            if let sComp = parseTime(sText, pack: pack), let eComp = parseTime(eText, pack: pack) {
                return TemporalToken(range: m.range, text: sub, kind: .timeRange(start: sComp, end: eComp))
            }
            return nil
        }

        // time-only
        add(pack.timeOnlyRegex()) { m, sub in
            if let comps = parseTime(sub, pack: pack) {
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

        // Handle "a month from now", "an hour from now" patterns
        add(pack.articleFromNowRegex()) { m, sub in
            let nsAll = text as NSString
            if m.numberOfRanges >= 3 {
                let unitS = nsAll.substring(with: m.range(at: 2))
                if let unit = unitFrom(unitS) {
                    let val = 1 // Articles always mean "1"
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

        if let dd = AppleDateDetector() {
            let ns = text as NSString
            dd.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { m in
                guard let date = m.date else { return }
                let substr = ns.substring(with: m.range)
                if let tre = pack.timeOnlyRegex() {
                    let full = NSRange(location: 0, length: (substr as NSString).length)
                    if let mm = tre.firstMatch(in: substr, options: [], range: full), mm.range.length == full.length {
                        if let comps = parseTime(substr, pack: pack) {
                            tokens.append(TemporalToken(range: m.range, text: substr, kind: .absoluteTime(comps)))
                            return
                        }
                    }
                }
                if hasRelativeCues(substr) { return }
                let comps = Calendar.current.dateComponents(in: calendar.timeZone, from: date)
                tokens.append(TemporalToken(range: m.range, text: substr, kind: .absoluteDate(comps)))
            }
        }

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

    // Time parsing helper
    func parseTime(_ s: String, pack: DateLanguagePack) -> DateComponents? {
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

    func parseTimeRange(_ firstTimeText: String, _ secondTimeText: String, pack: DateLanguagePack) -> (DateComponents, DateComponents)? {
        guard let firstComps = parseTime(firstTimeText, pack: pack),
              let secondComps = parseTime(secondTimeText, pack: pack) else {
            return nil
        }
        
        var adjustedFirst = firstComps
        var adjustedSecond = secondComps
        
        // Check if we need AM/PM propagation
        let firstHasAMPM = hasAMPMMarker(firstTimeText)
        let secondHasAMPM = hasAMPMMarker(secondTimeText)
        let secondAMPM = extractAMPMMarker(secondTimeText)
        
        // Case 1: "4-6pm" - first has no AM/PM, second has PM
        if !firstHasAMPM && secondHasAMPM && secondAMPM == "pm" {
            // Apply PM to first time if it makes logical sense
            if let firstHour = adjustedFirst.hour, firstHour < 12 {
                // Only apply PM if the range makes sense (e.g., 4-6pm, not 10-6pm)
                if let secondHour = adjustedSecond.hour, firstHour < (secondHour <= 12 ? secondHour : secondHour - 12) {
                    adjustedFirst.hour = firstHour + 12
                }
            }
        }
        
        // Case 2: "4am-6" - first has AM, second has no AM/PM
        else if firstHasAMPM && !secondHasAMPM {
            let firstAMPM = extractAMPMMarker(firstTimeText)
            if let secondHour = adjustedSecond.hour, let firstHour = adjustedFirst.hour {
                if firstAMPM == "am" && secondHour > (firstHour >= 12 ? firstHour - 12 : firstHour) {
                    // Keep second as AM (no change needed)
                } else if firstAMPM == "pm" && secondHour < 12 && secondHour > (firstHour >= 12 ? firstHour - 12 : firstHour) {
                    // Apply PM to second time
                    adjustedSecond.hour = secondHour + 12
                }
            }
        }
        
        // Validate the range makes sense (start < end)
        if let startHour = adjustedFirst.hour, let endHour = adjustedSecond.hour {
            let startMinutes = startHour * 60 + (adjustedFirst.minute ?? 0)
            let endMinutes = endHour * 60 + (adjustedSecond.minute ?? 0)
            
            if startMinutes >= endMinutes {
                // If end is not after start, try adjusting
                if endHour < 12 && startHour >= 12 {
                    // Maybe end should be PM too (e.g., "2pm-4" -> "2pm-4pm")
                    adjustedSecond.hour = endHour + 12
                }
            }
        }
        
        return (adjustedFirst, adjustedSecond)
    }
    
    private func hasAMPMMarker(_ timeText: String) -> Bool {
        let lower = timeText.lowercased()
        return lower.contains("am") || lower.contains("pm")
    }
    
    private func extractAMPMMarker(_ timeText: String) -> String? {
        let lower = timeText.lowercased()
        if lower.contains("pm") { return "pm" }
        if lower.contains("am") { return "am" }
        return nil
    }
    
    /// Returns true if the phrase itself contains relative cues that we should compose.
    private func hasRelativeCues(_ s: String, pack: DateLanguagePack) -> Bool {
        let range = NSRange(location: 0, length: (s as NSString).length)
        if pack.weekdayPhraseRegex().firstMatch(in: s, options: [], range: range) != nil { return true }
        if pack.weekMainRegex().firstMatch(in: s, options: [], range: range) != nil { return true }
        if let r = pack.relativeDayRegex(), r.firstMatch(in: s, options: [], range: range) != nil { return true }
        if let r = pack.partOfDayRegex(), r.firstMatch(in: s, options: [], range: range) != nil { return true }
        return false
    }
}

