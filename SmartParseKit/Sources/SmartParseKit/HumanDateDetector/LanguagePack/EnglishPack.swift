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
    public let weekdayMap: [String : Int]

    public init(calendar: Calendar) {
        var cal = calendar;
        if cal.locale == nil { cal.locale = Locale(identifier: "en_US") }
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
        BaseLanguagePack.regex(#"(?ix)\b(?:this|next)\s+week\b"#)
    }

    public func weekBareRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:plan(?:\s+my)?\s+week|my\s+week|the\s+week|week)\b"#)
    }

    public func inlineTimeRangeRegex() -> NSRegularExpression {
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let timeToken  = #"(?:\d{1,2}(?::\d{2})?\s*(?:am|pm|h)?)"#
        let preBetween = #"(?:\s+(?:at))?"#
        let sep        = #"(?:\s*(?:[-–—~]|to)\s*)"#
        let pat = #"""
        (?ix)\b
        (\#(weekdayAlt))\#(preBetween)\s+
        (\#(timeToken))
        (?:\#(sep)(\#(timeToken)))?
        \b
        """#
        return BaseLanguagePack.regex(pat)
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

