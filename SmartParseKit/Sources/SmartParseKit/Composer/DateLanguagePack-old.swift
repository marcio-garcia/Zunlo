
//import Foundation
//
//// MARK: - Protocol
//
//public protocol DateLanguagePack {
//    var calendar: Calendar { get }
//    var thisTokens: [String] { get }
//    var nextTokens: [String] { get }
//    var weekdayMap: [String: Int] { get }
//    var connectorTokens: [String] { get }
//
//    func weekdayPhraseRegex() -> NSRegularExpression
//    func weekMainRegex() -> NSRegularExpression
//    func weekBareRegex() -> NSRegularExpression
//    func inlineTimeRangeRegex() -> NSRegularExpression
//    func fromToTimeRegex() -> NSRegularExpression
//    func phraseIndicatesNext(_ phraseLowercased: String) -> Bool
//    func commandPrefixRegex() -> NSRegularExpression
//
//    // Optional detectors (default nil). Packs may override.
//    func weekendRegex() -> NSRegularExpression?
//    func relativeDayRegex() -> NSRegularExpression?
//    func partOfDayRegex() -> NSRegularExpression?
//    func ordinalDayRegex() -> NSRegularExpression?
//    func timeOnlyRegex() -> NSRegularExpression?
//    func betweenTimeRegex() -> NSRegularExpression?
//    func inFromNowRegex() -> NSRegularExpression?
//    func byOffsetRegex() -> NSRegularExpression?
//
//    // Count repetitions for "next next week". Default uses phraseIndicatesNext.
//    func nextRepetitionCount(in phrase: String) -> Int
//}
//
//public extension DateLanguagePack {
//    func weekendRegex() -> NSRegularExpression? { nil }
//    func relativeDayRegex() -> NSRegularExpression? { nil }
//    func partOfDayRegex() -> NSRegularExpression? { nil }
//    func ordinalDayRegex() -> NSRegularExpression? { nil }
//    func timeOnlyRegex() -> NSRegularExpression? { nil }
//    func betweenTimeRegex() -> NSRegularExpression? { nil }
//    func inFromNowRegex() -> NSRegularExpression? { nil }
//    func byOffsetRegex() -> NSRegularExpression? { nil }
//    func nextRepetitionCount(in phrase: String) -> Int { phraseIndicatesNext(phrase) ? 1 : 0 }
//}
//
//// MARK: - Base helpers
//
//public enum BaseLanguagePack {
//    public static func regex(_ pattern: String) -> NSRegularExpression {
//        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .allowCommentsAndWhitespace])
//    }
//
//    public static func weekdayAlternation(_ map: [String: Int]) -> String {
//        map.keys.sorted { $0.count > $1.count }.map(NSRegularExpression.escapedPattern).joined(separator: "|")
//    }
//
//    public static func makeWeekdayMap(calendar: Calendar) -> [String: Int] {
//        var map: [String: Int] = [:]
//        var cal = calendar
//        let loc = cal.locale ?? .current
//        cal.locale = loc
//
//        let fold: (String) -> String = { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: loc).lowercased() }
//
//        let full  = cal.weekdaySymbols.map { fold($0) }
//        let short = cal.shortWeekdaySymbols.map { fold($0).replacingOccurrences(of: ".", with: "") }
//        let very  = cal.veryShortWeekdaySymbols.map { fold($0) }
//
//        for w in 1...7 {
//            let f = full[w-1], s = short[w-1], v = very[w-1]
//            map[f] = w; map[s] = w; map[v] = w
//
//            let noHyphen = f.replacingOccurrences(of: "-", with: " ")
//            if noHyphen != f { map[noHyphen] = w }
//
//            if f.contains("segunda") { map["segunda"] = w }
//            if f.contains("terca") || f.contains("terça") { map["terca"] = w; map["terça"] = w }
//            if f.contains("quarta") { map["quarta"] = w }
//            if f.contains("quinta") { map["quinta"] = w }
//            if f.contains("sexta")  { map["sexta"]  = w }
//        }
//
//        let en3 = ["sun","mon","tue","wed","thu","fri","sat"]
//        for (i,key) in en3.enumerated() { map[key] = i+1 }
//        return map
//    }
//
//    // Accepts 09:30, 9, 9am, 21h, 21h30, 21 hs, 21 hrs
//    public static var timeToken: String {
//        return #"(?:(?:[01]?\d|2[0-3])(?::\d{2})?(?:\s*[hH]\s*\d{2})?)\s*(?:am|pm|hs?|hrs?)?"#
//    }
//
//    public static var timeTokenEN: String {
//        return #"(?:(?:[01]?\d|2[0-3])(?::\d{2})?)\s*(?:am|pm)?"#
//    }
//}
//
//// MARK: - English pack (improved)
//
//public struct EnglishPack: DateLanguagePack {
//    public let calendar: Calendar
//    public let thisTokens = ["this","coming"]
//    public let nextTokens = ["next"]
//    public var connectorTokens = ["at","on","from","to","until","till","by"]
//    public let weekdayMap: [String: Int]
//
//    public init(calendar: Calendar) {
//        var cal = calendar
//        if cal.locale == nil { cal.locale = Locale(identifier: "en_US") }
//        self.calendar = cal
//        self.weekdayMap = BaseLanguagePack.makeWeekdayMap(calendar: cal)
//    }
//
//    public func weekdayPhraseRegex() -> NSRegularExpression {
//        let thisAlt = thisTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
//        let nextAlt = nextTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
//        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
//        let pat = #"""
//        (?ix)\b
//        (?:(\#(thisAlt)|\#(nextAlt))\s+)?
//        (\#(weekdayAlt))
//        \b
//        """#
//        return BaseLanguagePack.regex(pat)
//    }
//
//    public func weekMainRegex() -> NSRegularExpression {
//        let thisAlt = thisTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
//        let nextAlt = nextTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
//        return BaseLanguagePack.regex(#"""
//        (?ix)\b
//        (?:
//            (?:\#(thisAlt))\s+week |
//            (?:(?:\#(nextAlt)\s+)+week)
//        )
//        \b
//        """#)
//    }
//
//    public func weekBareRegex() -> NSRegularExpression {
//        return BaseLanguagePack.regex(#"(?ix)\b(?:plan(?:\s+my)?\s+week|my\s+week|the\s+week|week)\b"#)
//    }
//
//    public func inlineTimeRangeRegex() -> NSRegularExpression {
//        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
//        let t = BaseLanguagePack.timeToken
//        let preBetween = #"(?:\s+(?:at))?"#
//        let sep = #"(?:\s*(?:[-–—~]|to)\s*)"#
//        let pat = #"""
//        (?ix)\b
//        (\#(weekdayAlt))\#(preBetween)\s+
//        (\#(t))
//        (?:\#(sep)(\#(t)))?
//        \b
//        """#
//        return BaseLanguagePack.regex(pat)
//    }
//
//    public func fromToTimeRegex() -> NSRegularExpression {
//        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
//        let t = BaseLanguagePack.timeTokenEN
//        let pat = #"""
//        (?ix)\b
//        (?:(\#(weekdayAlt))\s+)?
//        from\s+(\#(t))\s+to\s+(\#(t))
//        \b
//        """#
//        return BaseLanguagePack.regex(pat)
//    }
//
//    public func phraseIndicatesNext(_ s: String) -> Bool {
//        return s.range(of: #"(?i)\bnext\b"#, options: .regularExpression) != nil
//    }
//
//    public func commandPrefixRegex() -> NSRegularExpression {
//        let pat = #"""
//        (?ix)^ \s* (?:
//            (create|move|update|add|set\s*up|schedule|book|reschedule|postpone|delay|push\s*back|change|modify|delete|remove|cancel)
//            \s+ (?:an?\s+)? (?:event|task|reminder)?
//          | (don't\s+schedule|do\s+not\s+schedule)
//        )
//        (?: \s+ (?:for|to|on|at) )?
//        \s*
//        """#
//        return BaseLanguagePack.regex(pat)
//    }
//
//    // NEW detectors
//
//    public func weekendRegex() -> NSRegularExpression? {
//        return BaseLanguagePack.regex(#"(?ix)\b(?:(?:this|coming|next)\s+)?weekend\b"#)
//    }
//    public func relativeDayRegex() -> NSRegularExpression? {
//        return BaseLanguagePack.regex(#"(?ix)\b(?:today|tomorrow|tonight)\b"#)
//    }
//    public func partOfDayRegex() -> NSRegularExpression? {
//        return BaseLanguagePack.regex(#"(?ix)\b(?:morning|afternoon|evening|tonight|noon|midnight)\b"#)
//    }
//    public func ordinalDayRegex() -> NSRegularExpression? {
//        return BaseLanguagePack.regex(#"(?ix)\b(?:the\s*)?([12]?\d|3[01])(?:st|nd|rd|th)\b"#)
//    }
//    public func timeOnlyRegex() -> NSRegularExpression? {
//        let t = BaseLanguagePack.timeTokenEN
//        return BaseLanguagePack.regex(#"(?ix)\b(?:noon|midnight|\#(t))\b"#)
//    }
//    public func betweenTimeRegex() -> NSRegularExpression? {
//        let t = BaseLanguagePack.timeTokenEN
//        return BaseLanguagePack.regex(#"(?ix)\b between \s+ (\#(t)) \s+ (?:and|-|to) \s+ (\#(t)) \b"#)
//    }
//    public func inFromNowRegex() -> NSRegularExpression? {
//        return BaseLanguagePack.regex(#"(?ix)\b(?:in|within)\s+(\d+)\s+(minutes?|mins?|hours?|hrs?|days?|weeks?|months?)\b"#)
//    }
//    public func byOffsetRegex() -> NSRegularExpression? {
//        return BaseLanguagePack.regex(#"(?ix)\bby\s+(\d+)\s+(minutes?|mins?|hours?|hrs?|days?|weeks?|months?)\b"#)
//    }
//
//    public func nextRepetitionCount(in s: String) -> Int {
//        let re = try! NSRegularExpression(pattern: #"(?i)\b(next)(?:\s+next)*\s+week\b"#)
//        if let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) {
//            let sub = (s as NSString).substring(with: m.range)
//            return sub.lowercased().components(separatedBy: .whitespaces).filter { $0 == "next" }.count
//        }
//        return phraseIndicatesNext(s) ? 1 : 0
//    }
//}
