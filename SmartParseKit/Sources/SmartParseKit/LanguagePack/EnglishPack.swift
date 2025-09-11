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
    public var connectorTokens = ["at", "on", "from", "to", "until", "till", "by"]
    public let weekdayMap: [String : Int]

    public init(calendar: Calendar) {
        var cal = calendar;
        if cal.locale == nil { cal.locale = Locale(identifier: "en_US") }
        self.calendar = cal
        self.weekdayMap = BaseLanguagePack.makeWeekdayMap(calendar: cal)
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

    public func commandPrefixRegex() -> NSRegularExpression {
        let pat = #"""
        (?ix)^ \s* (?:
            (create|move|update|add|set\s*up|schedule|book|reschedule|postpone|delay|push\s*back|change|modify|delete|remove|cancel)
            \s+ (?:an?\s+)? (?:event|task|reminder)?
          | (don't\s+schedule|do\s+not\s+schedule)
        )
        (?: \s+ (?:for|to|on|at) )?
        \s*
        """#
        return BaseLanguagePack.regex(pat)
    }

    // NEW
    public func weekendRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:(?:this|coming|next)\s+)?weekend\b"#)
    }
    public func relativeDayRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:today|tomorrow|tonight)\b"#)
    }
    public func partOfDayRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:morning|afternoon|evening|tonight|noon|midnight)\b"#)
    }
    public func ordinalDayRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:the\s*)?([12]?\d|3[01])(?:st|nd|rd|th)\b"#) // group 1 = day
    }
    public func timeOnlyRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:noon|midnight|\#(BaseLanguagePack.timeTokenEN))\b"#)
    }
    public func betweenTimeRegex() -> NSRegularExpression {
        let t = BaseLanguagePack.timeTokenEN
        return BaseLanguagePack.regex(#"""
        (?ix)\b between \s+ (\#(t)) \s+ (?:and|-|to) \s+ (\#(t)) \b
        """#) // groups 1=start, 2=end
    }

    // Optional helper for "next next week"
    public func nextRepetitionCount(in s: String) -> Int {
        let re = try! NSRegularExpression(pattern: #"(?i)\b(next)(?:\s+next)*\s+week\b"#)
        guard let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return 0 }
        let sub = (s as NSString).substring(with: m.range)
        return sub.components(separatedBy: CharacterSet.whitespaces).filter { $0.caseInsensitiveCompare("next") == .orderedSame }.count
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

    public func weekBareRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:plan(?:\s+my)?\s+week|my\s+week|the\s+week|week)\b"#)
    }

    public func fromToTimeRegex() -> NSRegularExpression {
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let timeToken  = #"(?:\d{1,2}(?::\d{2})?\s*(?:am|pm|h)?)"#
        let pat = #"""
        (?ix)\b
        (?:(\#(weekdayAlt))\s+)?
        from\s+(\#(timeToken))\s+to\s+(\#(timeToken))
        \b
        """#
        return BaseLanguagePack.regex(pat)
    }

    public func phraseIndicatesNext(_ s: String) -> Bool {
        s.range(of: #"(?i)\bnext\b"#, options: .regularExpression) != nil
    }
}
