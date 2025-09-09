//
//  SpanishPack.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/8/25.
//

import Foundation

public struct SpanishPack: DateLanguagePack {
    public let calendar: Calendar
    public let thisTokens = ["este", "esta"]
    public let nextTokens = ["próximo", "proximo", "próxima", "proxima", "siguiente", "que viene"]
    public var connectorTokens = ["a las", "desde", "hasta", "en", "el", "la"]
    public let weekdayMap: [String : Int]

    // Convenience: access the locale from the calendar
    private var locale: Locale { calendar.locale ?? .current }

    public init(calendar: Calendar) {
        var cal = calendar
        if cal.locale == nil {
            // Prefer generic Spanish; switch to es_419 if you want LATAM defaults
            cal.locale = Locale(identifier: "es_ES")
        }
        self.calendar = cal

        // Build robust weekday map (includes localized names AND en 3-letter aliases)
        self.weekdayMap = BaseLanguagePack.makeWeekdayMap(calendar: cal)
    }

    // MARK: - Regex builders

    public func weekdayPhraseRegex() -> NSRegularExpression {
        // Optional modifier + optional article + weekday + optional “que viene”
        // Groups:
        //   (1) modifier (optional)
        //   (2) weekday (required)
        let thisAlt = thisTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let nextAlt = nextTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let pat = #"""
        (?ix)\b
        (?:
           ((?:\#(thisAlt))|(?:\#(nextAlt)))\s+
        )?
        (?:el|la)?\s*
        (\#(weekdayAlt))
        (?:\s+que\s+viene)?
        \b
        """#
        return BaseLanguagePack.regex(pat)
    }

    public func weekMainRegex() -> NSRegularExpression {
        // “esta semana”, “(la) próxima semana”, “semana que viene”
        let thisAlt = thisTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let nextAlt = nextTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let pat = #"""
        (?ix)\b
        (?:
            (?:\#(thisAlt))\s+semana |
            (?:la\s+)?(?:\#(nextAlt))\s+semana |
            semana\s+que\s+viene
        )
        \b
        """#
        return BaseLanguagePack.regex(pat)
    }

    public func weekBareRegex() -> NSRegularExpression {
        // “planificar mi semana”, “mi semana”, “agenda de la semana”, “planear mi semana”, “semana”
        let pat = #"""
        (?ix)\b(?:
            planificar\s+mi\s+semana |
            planear\s+mi\s+semana   |
            mi\s+semana             |
            agenda\s+de\s+la\s+semana |
            \bsemana\b
        )
        """#
        return BaseLanguagePack.regex(pat)
    }

    public func inlineTimeRangeRegex() -> NSRegularExpression {
        // “mié a las 9-10”, “miercoles 14-16”, allow separators -, ~, “a”
        // Groups: 1=weekday, 2=start time, 3=end time (optional)
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let timeToken  = #"(?:\d{1,2}(?::\d{2})?\s*(?:am|pm|h)?)"#
        let preBetween = #"(?:\s+(?:a\s+las|a|en|a\slas))?"#
        let sep        = #"(?:\s*(?:[-–—~]|a)\s*)"#
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
        // “(miércoles )de 9 a 10”, “(mié )desde 9 hasta 10”, also accept “from 9 to 10”
        // Groups: 1=weekday (optional), 2=start, 3=end
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let timeToken  = #"(?:\d{1,2}(?::\d{2})?\s*(?:am|pm|h)?)"#
        let pat = #"""
        (?ix)\b
        (?:(\#(weekdayAlt))\s+)?
        (?:
            de|desde|from
        )\s+
        (\#(timeToken))
        \s+
        (?:
            a|hasta|to
        )\s+
        (\#(timeToken))
        \b
        """#
        return BaseLanguagePack.regex(pat)
    }
    
    public func commandPrefixRegex() -> NSRegularExpression {
        let pat = #"""
        (?ix) ^
        \s* (?:
            (crear|mover|actualizar|agregar|programar|reservar|nuevo|add|reservar|tener un) \s+ (?:un\s+)? (?:evento|tarea|recordatorio) |
            agregar \s+ (?:un\s+)? recordatorio |
            programar \s+ (?:un\s+)? (?:evento|tarea|recordatorio) |
            programar |
            establecer \s+ (?:un\s+)? recordatorio
        )
        (?: \s+ (?:para|a|en) )?
        \s*
        """#
        return BaseLanguagePack.regex(pat)
    }

    // MARK: - Semantics

    public func phraseIndicatesNext(_ s: String) -> Bool {
        let l = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale)
        return l.contains("proximo")
            || l.contains("proxima")
            || l.contains("siguiente")
            || l.contains("que viene")
            || l.contains("next")
    }
}
