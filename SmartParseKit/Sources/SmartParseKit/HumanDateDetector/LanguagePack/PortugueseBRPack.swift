//
//  PortugueseBRPack.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/8/25.
//

import Foundation

public struct PortugueseBRPack: DateLanguagePack {
    public let calendar: Calendar
    public let thisTokens = ["este","esta","neste","nesta","deste","desta","agora","nessa"]
    public let nextTokens = ["próximo","proximo","no próximo","no proximo","na próxima","na proxima","seguinte","que vem"]
    public let weekdayMap: [String : Int]

    public init(calendar: Calendar) {
        var cal = calendar
        let loc = cal.locale ?? Locale(identifier: "pt_BR")
        cal.locale = loc
        self.calendar = cal
        self.weekdayMap = BaseLanguagePack.makeWeekdayMap(calendar: cal)
    }

    public func weekdayPhraseRegex() -> NSRegularExpression {
        let thisAlt = thisTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let nextAlt = nextTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let pat = #"""
        (?ix)\b
        (?:(\#(thisAlt)|\#(nextAlt))\s+(?:o|a|no|na|neste|nesta|deste|desta)?\s*)?
        (\#(weekdayAlt))
        (?:\s+que\s+vem)?
        \b
        """#
        return BaseLanguagePack.regex(pat)
    }

    public func weekMainRegex() -> NSRegularExpression {
        let thisAlt = thisTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let nextAlt = nextTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        return BaseLanguagePack.regex(#"""
        (?ix)\b
        (?:\#(thisAlt)|\#(nextAlt)|que\s+vem)
        \s*(?:a|o|na|no|desta|deste|nesta|neste)?\s*semana\b
        """#)
    }

    // "Bare" week cues (no explicit this/next): plan my week / minha semana / agenda da semana / this agenda week-ish)
    public func weekBareRegex() -> NSRegularExpression {
        return BaseLanguagePack.regex(#"""
        (?ix)\b(?:
          agenda\s+(?:da|de|para)\s+semana |
          minha\s+semana |
          meu\s+planejamento\s+da\s+semana |
          \bsemana\b
        )
        """#)
    }

    public func inlineTimeRangeRegex() -> NSRegularExpression {
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let timeToken  = #"(?:\d{1,2}(?::\d{2})?\s*(?:am|pm|h|hs|hrs)?)"#
        let preBetween = #"(?:\s+(?:às|as|a))?"#
        let sep        = #"(?:\s*(?:[-–—~]|a|às|to)\s*)"#
        let pat = #"""
        (?ix)\b
        (\#(weekdayAlt))\#(preBetween)\s+
        (\#(timeToken))
        (?:\#(sep)(\#(timeToken)))?
        \b
        """#
        return BaseLanguagePack.regex(pat)
    }

    // --- Portuguese/English "from-to" with optional weekday in front ---
    // Examples:
    //   "quarta das 9 às 10", "qua das 10h às 12h", "quarta de 14 a 16"
    //   "from 9 to 10", (EN)
    // Notes:
    //   • Group 1: optional weekday
    //   • Group 2: start time
    //   • Group 3: end time
    public func fromToTimeRegex() -> NSRegularExpression {
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let timeToken  = #"(?:\d{1,2}(?::\d{2})?\s*(?:am|pm|h|hs|hrs)?)"#
        let pat = #"""
        (?ix)\b
        (?:(\#(weekdayAlt))\s+)?
        (?:(?:das|de|from))\s+
        (\#(timeToken))\s+
        (?:(?:às|as|a|to))\s+
        (\#(timeToken))
        \b
        """#
        return BaseLanguagePack.regex(pat)
    }

    public func phraseIndicatesNext(_ s: String) -> Bool {
        let l = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: calendar.locale ?? .current)
        return l.contains("proximo") || l.contains("próximo") || l.contains("seguinte") || l.contains("que vem") || l.contains("next")
    }
}
