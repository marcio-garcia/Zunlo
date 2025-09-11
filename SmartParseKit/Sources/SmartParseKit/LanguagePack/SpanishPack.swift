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

    public func weekMainRegex() -> NSRegularExpression {
        let thisAlt = thisTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let nextAlt = nextTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        return BaseLanguagePack.regex(#"""
        (?ix)\b
        (?:
            (?:\#(thisAlt))\s+semana |
            (?:(?:\#(nextAlt)\s+)+semana) |
            semana\s+que\s+viene
        )
        \b
        """#)
    }

    public func inlineTimeRangeRegex() -> NSRegularExpression {
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let t = BaseLanguagePack.timeToken
        let preBetween = #"(?:\s+(?:a\s+las|a|en))?"#
        let sep = #"(?:\s*(?:[-–—~]|a)\s*)"#
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
        let t = BaseLanguagePack.timeToken
        return BaseLanguagePack.regex(#"""
        (?ix)\b
        (?:(\#(weekdayAlt))\s+)?
        (?:(?:de|desde|from))\s+ (\#(t)) \s+ (?:(?:a|hasta|to)) \s+ (\#(t)) \b
        """#)
    }

    // NEW
    public func weekendRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:(?:\#(thisTokens.joined(separator:"|"))|\#(nextTokens.joined(separator:"|")))\s+)?fin\s+de\s+semana\b"#)
    }
    public func relativeDayRegex() -> NSRegularExpression {
        // Standalone "mañana" = tomorrow; "por/en/de la mañana" = part of day (handled below)
        BaseLanguagePack.regex(#"(?ix)\b(?:hoy|mañana|esta\s+noche)\b"#)
    }
    public func partOfDayRegex() -> NSRegularExpression {
        // Require prepositions to avoid clashing with "mañana = tomorrow"
        BaseLanguagePack.regex(#"(?ix)\b(?:(?:por|en|de)\s+la\s+)?(?:mañana|tarde|noche)|mediod[ií]a|medianoche\b"#)
    }
    public func ordinalDayRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:d[ií]a\s*)?([12]?\d|3[01])(?:º|o)?\b"#)
    }
    public func timeOnlyRegex() -> NSRegularExpression {
        let t = BaseLanguagePack.timeToken
        return BaseLanguagePack.regex(#"(?ix)\b(?:mediod[ií]a|medianoche|\#(t))\b"#)
    }
    public func betweenTimeRegex() -> NSRegularExpression {
        let t = BaseLanguagePack.timeToken
        return BaseLanguagePack.regex(#"""
        (?ix)\b (?:entre)\s+ (\#(t)) \s+ (?:y|-|a)\s+ (\#(t)) \b
        """#)
    }


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
