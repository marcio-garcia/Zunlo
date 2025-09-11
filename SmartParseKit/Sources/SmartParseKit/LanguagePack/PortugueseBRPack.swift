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
    public var connectorTokens = ["às", "as", "das", "de", "até", "a", "no", "na", "em"]
    public let weekdayMap: [String : Int]

    public init(calendar: Calendar) {
        var cal = calendar
        let loc = cal.locale ?? Locale(identifier: "pt_BR")
        cal.locale = loc
        self.calendar = cal
        self.weekdayMap = BaseLanguagePack.makeWeekdayMap(calendar: cal)
    }

    public func weekMainRegex() -> NSRegularExpression {
        let thisAlt = thisTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let nextAlt = nextTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        return BaseLanguagePack.regex(#"""
        (?ix)\b
        (?:
          (?:\#(thisAlt)) \s* (?:a|o|na|no|desta|deste|nesta|neste)? \s* semana |
          (?:(?:\#(nextAlt)\s*)+)(?:a|o|na|no)?\s*semana |
          semana \s+ que \s+ vem
        )
        \b
        """#)
    }

    public func inlineTimeRangeRegex() -> NSRegularExpression {
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let t = BaseLanguagePack.timeToken
        let preBetween = #"(?:\s+(?:às|as|a))?"#
        let sep = #"(?:\s*(?:[-–—~]|a|às|as|to)\s*)"#
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
        (?:(?:das|de|from))\s+ (\#(t)) \s+ (?:(?:às|as|a|to)) \s+ (\#(t)) \b
        """#)
    }

    // NEW
    public func weekendRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:(?:\#(thisTokens.joined(separator:"|"))|\#(nextTokens.joined(separator:"|")))\s+)?fim\s+de\s+semana\b"#)
    }
    public func relativeDayRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:hoje|amanh[ãa]|esta\s+noite)\b"#)
    }
    public func partOfDayRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:manh[ãa]|tarde|noite|meio[-\s]?dia|meia[-\s]?noite)\b"#)
    }
    public func ordinalDayRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:dia\s*)?([12]?\d|3[01])(?:º|o)?\b"#)
    }
    public func timeOnlyRegex() -> NSRegularExpression {
        let t = BaseLanguagePack.timeToken
        return BaseLanguagePack.regex(#"(?ix)\b(?:meio[-\s]?dia|meia[-\s]?noite|\#(t))\b"#)
    }
    public func betweenTimeRegex() -> NSRegularExpression {
        let t = BaseLanguagePack.timeToken
        return BaseLanguagePack.regex(#"""
        (?ix)\b (?:entre)\s+ (\#(t)) \s+ (?:e|-|a)\s+ (\#(t)) \b
        """#)
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
    
    public func commandPrefixRegex() -> NSRegularExpression {
        // Matches at start (case/diacritic insensitive):
        // "adicionar lembrete", "criar (evento|lembrete|tarefa)", "agendar",
        // "marcar", "definir (um )?lembrete", optionally followed by "para|de|do|da"
        let pat = #"""
        (?ix) ^
        \s* (?:
            (criar|mover|atualizar|adicionar|agendar|marcar|novo|add|reservar|tenho um|colocar) \s+ (?:um\s+)? (?:evento|lembrete|tarefa) |
            agendar |
            marcar |
            definir \s+ (?:um\s+)? lembrete |
            preciso adicionar \s+ (?:um\s+)? lembrete
        )
        (?: \s+ (?:para|de|do|da) )?
        \s*
        """#
        return BaseLanguagePack.regex(pat)
    }


    public func phraseIndicatesNext(_ s: String) -> Bool {
        let l = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: calendar.locale ?? .current)
        return l.contains("proximo") || l.contains("próximo") || l.contains("seguinte") || l.contains("que vem") || l.contains("next")
    }
}
