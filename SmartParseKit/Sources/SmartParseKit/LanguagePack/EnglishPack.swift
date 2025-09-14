//
//  EnglishPack.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/8/25.
//

import Foundation

public struct EnglishPack: DateLanguagePack {
    public let calendar: Calendar
    public let thisTokens = ["this", "coming"]
    public let nextTokens = ["next"]
    public var connectorTokens = ["at", "on", "from", "to", "until", "till", "by", "for"]
    public let weekdayMap: [String: Int]

    public init(calendar: Calendar) {
        var cal = calendar
        cal.locale = Locale(identifier: "en_US")
        self.calendar = cal
        self.weekdayMap = BaseLanguagePack.makeWeekdayMap(calendar: cal)
    }

    public func weekdayPhraseRegex() -> NSRegularExpression {
        let thisAlt = thisTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let nextAlt = nextTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let pat = #"""
        (?ix)\b
        (?:(\#(thisAlt)|\#(nextAlt))\s+)?
        (\#(weekdayAlt))
        \b
        """#
        return BaseLanguagePack.regex(pat)
    }

    public func weekMainRegex() -> NSRegularExpression {
        let thisAlt = thisTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|") // this|coming
        let nextAlt = nextTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|") // next
        // e.g. "this week", "coming week", "next week", "next next week"
        return BaseLanguagePack.regex(#"""
        (?ix)\b
        (?:
            (?:\#(thisAlt))\s+week |
            (?:(?:\#(nextAlt)\s+)+week)
        )
        \b
        """#)
    }

    public func weekBareRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:plan(?:\s+my)?\s+week|my\s+week|the\s+week|week)\b"#)
    }

    public func inlineTimeRangeRegex() -> NSRegularExpression {
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let t = BaseLanguagePack.timeToken // supports 20h30
        let preBetween = #"(?:\s+(?:at))?"#
        let sep = #"(?:\s*(?:[-–—~]|to)\s*)"#
        return BaseLanguagePack.regex(#"""
        (?ix)\b
        (\#(weekdayAlt))\#(preBetween)\s+
        (\#(t))
        (?:\#(sep)(\#(t)))?
        \b
        """#)
    }

    public func fromToTimeRegex() -> NSRegularExpression {
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let t = BaseLanguagePack.timeTokenEN
        let pat = #"""
        (?ix)\b
        (?:(\#(weekdayAlt))\s+)?
        from\s+(\#(t))\s+to\s+(\#(t))
        \b
        """#
        return BaseLanguagePack.regex(pat)
    }

    public func phraseIndicatesNext(_ s: String) -> Bool { s.range(of: #"(?i)\bnext\b"#, options: .regularExpression) != nil }

    public func commandPrefixRegex() -> [NSRegularExpression] {
        return [
            intentViewRegex(),
            intentPlanRegex(),
            timePivotRegex(),
            intentCreateTaskRegex(),
            intentCreateEventRegex(),
            intentCancelTaskRegex(),
            intentCancelEventRegex(),
            intentCreateRegex(),
            intentRescheduleRegex(),
            intentCancelRegex(),
            intentUpdateRegex()
        ]
    }

    public func intentCreateRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?ix)\b(create|add|schedule|book|set\s*up)\b"#) }
    public func intentRescheduleRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?ix)\b(reschedul|rebook|postpone|push\s*back|delay|move|change|modify)\b"#) }
    public func intentCancelRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?ix)\b(delete|remove|cancel|don't\s+schedule|do\s+not\s+schedule)\b"#) }
    public func intentViewRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?ix)\b(show|view|what's\s+on|agenda|my\s+schedule)\b"#) }
    public func intentPlanRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?ix)\b(plan|organize|structure|map\s+out)\b"#) }
    public func timePivotRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?ix)\b(?:at|to)\b"#) }
    
    // Enhanced create patterns that combine action + type
    public func intentCreateTaskRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(add|create|make|set\s*up)\s+(?:a\s+)?(?:new\s+)?(task|todo|to\s*do|reminder|note|assignment|action\s+item)\b"#)
    }

    public func intentCreateEventRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(schedule|book|add|create|set\s*up)\s+(?:a\s+)?(?:new\s+)?(meeting|event|appointment|call|lunch|dinner|conference|session)\b"#)
    }

    // Enhanced cancel patterns that combine action + type
    public func intentCancelTaskRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(delete|remove|cancel|complete|finish|mark\s+done)\s+(?:the\s+)?(?:this\s+)?(task|todo|to\s*do|reminder|note|assignment|action\s+item)\b"#)
    }

    public func intentCancelEventRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(cancel|delete|remove|call\s+off)\s+(?:the\s+)?(?:this\s+)?(meeting|event|appointment|call|lunch|dinner|conference|session)\b"#)
    }

    // Update intent regex
    public func intentUpdateRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(update|edit|modify|change\s+details|alter)\b"#)
    }

    // Keyword detection (fallback)
    public func taskKeywordsRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(task|todo|to\s*do|reminder|note|assignment|action\s+item|chore|work)\b"#)
    }

    public func eventKeywordsRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(meeting|event|appointment|call|lunch|dinner|conference|session|gathering|party|ceremony)\b"#)
    }

    public func weekendRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(?:(?:this|coming|next)\s+)?weekend\b"#)
    }
    public func relativeDayRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(?:today|tomorrow|tonight)\b"#)
    }
    public func partOfDayRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(?:morning|afternoon|evening|tonight|noon|midnight)\b"#)
    }
    public func ordinalDayRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(?:the\s*)?([12]?\d|3[01])(?:st|nd|rd|th)\b"#) // group 1 = day
    }
    public func timeOnlyRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(?:noon|midnight|\#(BaseLanguagePack.timeTokenEN))\b"#)
    }
    
    public func betweenTimeRegex() -> NSRegularExpression? {
        let t = BaseLanguagePack.timeTokenEN
        return BaseLanguagePack.regex(#"""
        (?ix)\b between \s+ (\#(t)) \s+ (?:and|-|to) \s+ (\#(t)) \b
        """#) // groups 1=start, 2=end
    }

    public func inFromNowRegex() -> NSRegularExpression? { BaseLanguagePack.regex(#"(?ix)\b(?:in|within)\s+(\d+)\s+(minutes?|mins?|hours?|hrs?|days?|weeks?|months?)\b"#) }
    public func byOffsetRegex() -> NSRegularExpression? { BaseLanguagePack.regex(#"(?ix)\bby\s+(\d+)\s+(minutes?|mins?|hours?|hrs?|days?|weeks?|months?)\b"#) }


    // Optional helper for "next next week"
    public func nextRepetitionCount(in s: String) -> Int {
        let re = try! NSRegularExpression(pattern: #"(?i)\b(next)(?:\s+next)*\s+week\b"#)
        if let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) {
            let sub = (s as NSString).substring(with: m.range)
            return sub.lowercased().split(separator: " ").filter { $0 == "next" }.count
        }
        return phraseIndicatesNext(s) ? 1 : 0
    }

    public func classifyRelativeDay(_ l: String) -> RelativeDay? {
        if l.contains("tomorrow") { return .tomorrow }
        if l.contains("tonight") { return .tonight }
        if l.contains("today") { return .today }
        return nil
    }

    public func classifyPartOfDay(_ l: String) -> PartOfDay? {
        if l.contains("morning") { return .morning }
        if l.contains("afternoon") { return .afternoon }
        if l.contains("evening") { return .evening }
        if l.contains("tonight") { return .night }
        if l.contains("noon") { return .noon }
        if l.contains("midnight") { return .midnight }
        return nil
    }
}
