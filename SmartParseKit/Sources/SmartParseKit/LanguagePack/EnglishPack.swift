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
        (\#(weekdayAlt))?\#(preBetween)(\s+)?
        (\#(t))
        (?:\#(sep)(\#(t)))?
        \b
        """#)
    }

    public func fromToTimeRegex() -> NSRegularExpression {
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let t = BaseLanguagePack.timeToken
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
    public func intentRescheduleRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?ix)\b(reschedul\S+|rebook|postpone|push|push\s*back|delay|move|change|modify)\b"#) }
    public func intentCancelRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?ix)\b(delete|remove|cancel|don't\s+schedule|do\s+not\s+schedule)\b"#) }
    public func intentViewRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?ix)\b(display|show|view|what's\s+on|agenda|my\s+schedule|calendar)\b"#) }
    public func intentPlanRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?ix)\b(plan|organize|structure|map\s+out)\b"#) }
    public func timePivotRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?ix)\b(?:at|to)\b"#) }
    
    // Enhanced create patterns that combine action + type
    public func intentCreateTaskRegex() -> NSRegularExpression {
        //BaseLanguagePack.regex(#"(?ix)\b(add|create)\s+(?:a\s+)?(?:new\s+)?(task|todo|to\s*do|reminder|note|assignment|action\s+item)\b"#)
        BaseLanguagePack.regex(#"(?ix)\b(add|create)\s+(?:a\s+)?(?:new\s+)?.*\b"#)
    }

    public func intentCreateEventRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(schedule|book|add|create|set\s*up|block)\s+(?:a\s+)?(?:new\s+)?.*\b"#)
    }

    // Enhanced cancel patterns that combine action + type
    public func intentCancelTaskRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(delete|remove|cancel|complete|finish|mark\s+done)\s+(?:the\s+)?(?:this\s+)?(task|todo|to\s*do|reminder|note|assignment|action\s+item)\b"#)
    }

    public func intentCancelEventRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(cancel|delete|remove|call\s+off)\s+(?:the\s+)?(?:this\s+)?.*\b"#)
    }

    // Update intent regex
    public func intentUpdateRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(update|edit|modify|change\s+details|alter|rename)\b"#)
    }

    // Keyword detection (fallback)
    public func taskKeywordsRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(task|todo|to\s*do|reminder|note)\b"#)
    }

    public func eventKeywordsRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(event)\b"#)
    }

    // Metadata addition detection patterns
    public func metadataAdditionWithPrepositionRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"\b(add|set)\s+((tag|priority|reminder|note|location)(:)?\s+)(\S+)?((to|for)\s+)?(task|event|meeting|appointment)?\b"#)
    }

    public func metadataAdditionDirectRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(add|set)\s+(tag|priority|reminder|note|location)\s+\S+.*\b"#)
    }

    public func taskEventReferenceRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(task|event|meeting|appointment|item)\b"#)
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
        BaseLanguagePack.regex(#"\b(?:noon|midnight|\#(BaseLanguagePack.timeToken))\b"#)
    }
    
    public func betweenTimeRegex() -> NSRegularExpression? {
        let t = BaseLanguagePack.timeToken
        return BaseLanguagePack.regex(#"""
        (?ix)\b between \s+ (\#(t)) \s+ (?:and|-|to) \s+ (\#(t)) \b
        """#) // groups 1=start, 2=end
    }

    public func inFromNowRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(?:in|within)\s+(\d+)\s+(minutes?|mins?|hours?|hrs?|days?|weeks?|months?)\b"#)
    }

    public func articleFromNowRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(a|an)\s+(minute|hour|day|week|month|year)s?\s+from\s+now\b"#)
    }
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

    // MARK: - Metadata Pattern Implementation

    public func tagPatternRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"""
        (?ix)
        \b(?:with\s+)?tags?\s+(\S+(?:,\S+)*)(?:\s+(?:to|for))?\b
        |
        \btags?\s*[:=]\s*(\S+(?:,\S+)*)\b
        |
        \b(?:tagged\s+(?:as\s+)?|label(?:ed)?\s+(?:as\s+)?|category\s+)(\S+)\b
        """#) // groups 1, 2, or 3 = tag name(s)
    }

    public func reminderPatternRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"""
        (?ix)
        \b(?:remind\s+me|set\s+(?:a\s+)?reminder|with\s+(?:a\s+)?reminder|alert\s+me|add\s+reminder)
        (?:\s+(?:in|at|for))?\s+
        (?:(\d+)\s+(minutes?|mins?|hours?|hrs?|days?)\s+(?:before|early)
        |(?:at\s+)?(\d{1,2}(?::\d{2})?)(?:\s*(?:am|pm))?
        |(\d+)\s+(minutes?|mins?|hours?|hrs?|days?))\b
        """#) // groups: 1=number, 2=unit, 3=time, 4=offset_number, 5=offset_unit
    }

    public func priorityPatternRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"""
        (?ix)
        \b(?:(?:set\s+)?priority\s+(?:to\s+|as\s+)?
        |(?:mark\s+(?:as\s+)?)?(?:priority\s+)?)
        (urgent|high|medium|normal|low|critical|important)
        (?:\s+priority)?\b
        |
        \b(urgent|high|medium|normal|low|critical|important)(?:\s+priority)?\b
        """#) // groups 1 or 2 = priority level
    }

    public func locationPatternRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"""
        (?ix)
        \b(?:at|in|location\s*[:=]?)\s+
        (?:the\s+)?([a-zA-ZÀ-ÿ0-9\s_-]{2,50}?)
        (?=\s+(?:tomorrow|today|yesterday|next|this|on|for|with|and|or|but|at|\d|$)|[.!?,:;]|$)
        |
        \blocation\s*[:=]\s*([a-zA-ZÀ-ÿ0-9\s_-]{2,50})
        """#) // groups 1 or 2 = location name
    }

    public func notesPatternRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"""
        (?ix)
        \b(?:notes?|comments?|description)\s*[:=]\s*([^.!?;]{1,200})(?=[.!?;]|$)
        """#) // group 1 = notes content
    }

    public func classifyPriority(_ matchedLowercased: String) -> TaskPriority? {
        let text = matchedLowercased.lowercased()
        if text.contains("urgent") || text.contains("critical") {
            return .urgent
        } else if text.contains("high") || text.contains("important") {
            return .high
        } else if text.contains("medium") || text.contains("normal") {
            return .medium
        } else if text.contains("low") {
            return .low
        }
        return nil
    }

    public func extractReminderOffset(_ matchedText: String) -> TimeInterval? {
        let text = matchedText.lowercased()
        let regex = try? NSRegularExpression(pattern: #"(\d+)\s+(minutes?|mins?|hours?|hrs?|days?)"#, options: .caseInsensitive)

        guard let match = regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let numberRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let number = Double(String(text[numberRange])) else {
            return nil
        }

        let unit = String(text[unitRange])
        switch unit {
        case let u where u.hasPrefix("min"):
            return number * 60
        case let u where u.hasPrefix("hour") || u.hasPrefix("hr"):
            return number * 3600
        case let u where u.hasPrefix("day"):
            return number * 86400
        default:
            return nil
        }
    }
}
