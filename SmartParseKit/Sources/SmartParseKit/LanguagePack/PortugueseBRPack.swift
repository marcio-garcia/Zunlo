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
    public let nextTokens = ["próximo","proximo","no próximo","no proximo","próxima","proxima","na próxima","na proxima","seguinte","que vem"]
    public var connectorTokens = ["às","as","a","no","na","em","de","das","até","ao","pela","pelas","pelo","pelos","para"]
    public let weekdayMap: [String: Int]

    public init(calendar: Calendar) {
        var cal = calendar
        let loc = Locale(identifier: "pt_BR")
        cal.locale = loc
        self.calendar = cal
        self.weekdayMap = BaseLanguagePack.makeWeekdayMap(calendar: cal)
    }

    public func weekdayPhraseRegex() -> NSRegularExpression {
        let thisAlt = thisTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let nextAlt = nextTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        return BaseLanguagePack.regex(#"""
        (?ix)\b
        (?:(\#(thisAlt)|\#(nextAlt))\s+(?:o|a|no|na|neste|nesta|deste|desta)?\s*)?
        (\#(weekdayAlt))
        (?:\s+que\s+vem)?
        \b
        """#)
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

    public func weekBareRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"""
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
        let preBetween = #"(?:\s+(?:às|as|a|pra|para))?"#
        let sep        = #"(?:\s*(?:[-–—~]|a|às|as|to)\s*)"#
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
        let timeToken  = #"(?:\d{1,2}(?::\d{2})?\s*(?:am|pm|h|hs|hrs)?)"#
        return BaseLanguagePack.regex(#"""
        (?ix)\b
        (?:(\#(weekdayAlt))\s+)?
        (?:(?:das|de|from))\s+
        (\#(timeToken))\s+
        (?:(?:às|as|a|até|to))\s+
        (\#(timeToken))
        \b
        """#)
    }

    public func phraseIndicatesNext(_ s: String) -> Bool {
        let l = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: calendar.locale ?? .current)
        let contains = nextTokens.filter({ l.contains($0) })
        return !contains.isEmpty
    }

    public func commandPrefixRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"""
        (?ix) ^
        \s* (?:
            (criar|mover|atualizar|adicionar|agendar|marcar|novo|add|reservar|tenho\s+um|colocar|reagendar|remarcar|adiar|postergar) \s+ (?:um\s+)? (?:evento|lembrete|tarefa) |
            agendar | marcar |
            definir \s+ (?:um\s+)? lembrete |
            preciso \s+ adicionar \s+ (?:um\s+)? lembrete
        )
        (?: \s+ (?:para|de|do|da|no|na|em|às|as|a) )?
        \s*
        """#)
    }

    // Intents
    public func intentCreateRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(criar|adicionar|agendar|marcar|definir|reservar)\b"#)
    }
    public func intentRescheduleRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(remarcar|reagendar|adiar|postergar|empurrar|mudar|alterar|trocar|mover)\b"#)
    }
    public func intentCancelRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(deletar|apagar|remover|cancelar|n[aã]o\s+agendar|nao\s+agendar)\b"#)
    }
    public func intentViewRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(mostrar|ver|minha\s+agenda|agenda|meu\s+calend[aá]rio|calendario|o\s+que\s+(h[aá]|tem))\b"#)
    }
    public func intentPlanRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(planejar|organizar|estruturar|mapear)\b"#)
    }
    public func timePivotRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:às|as|a|pra|pras|para|das|de|desde|at[eé])\b"#)
    }
    public func weekendRegex() -> NSRegularExpression? { BaseLanguagePack.regex(#"(?ix)\b(?:(?:este|esta|proximo|próximo|seguinte)\s+)?fim\s*de\s*semana\b"#) }
    public func relativeDayRegex() -> NSRegularExpression? { BaseLanguagePack.regex(#"(?ix)\b(?:hoje|amanh[ãa]|esta\s+noite)\b"#) }
    public func partOfDayRegex() -> NSRegularExpression? { BaseLanguagePack.regex(#"(?ix)\b(?:manh[ãa]|tarde|noite|meio\s*dia|meia\s*noite)\b"#) }
    public func ordinalDayRegex() -> NSRegularExpression? { BaseLanguagePack.regex(#"(?ix)\b(?:dia\s*)?([12]?\d|3[01])(?:º|ª|o)?\b"#) }
    public func timeOnlyRegex() -> NSRegularExpression? {
        let t = #"(?:(?:[01]?\d|2[0-3])(?::\d{2})?\s*(?:h|hs|hrs)?)"#
        return BaseLanguagePack.regex(#"(?ix)\b(?:meio\s*dia|meia\s*noite|\#(t))\b"#)
    }
    public func betweenTimeRegex() -> NSRegularExpression? {
        let t = #"(?:(?:[01]?\d|2[0-3])(?::\d{2})?\s*(?:h|hs|hrs)?)"#
        return BaseLanguagePack.regex(#"(?ix)\b entre \s+ (\#(t)) \s+ (?:e|-|a|até) \s+ (\#(t)) \b"#)
    }
    public func inFromNowRegex() -> NSRegularExpression? { BaseLanguagePack.regex(#"(?ix)\b(?:em|dentro\s+de)\s+(\d+)\s+(minutos?|mins?|horas?|hrs?|dias?|semanas?|meses?)\b"#) }
    public func byOffsetRegex() -> NSRegularExpression? { BaseLanguagePack.regex(#"(?ix)\b(?:adiar|postergar)\s+em\s+(\d+)\s+(minutos?|mins?|horas?|hrs?|dias?|semanas?|meses?)\b"#) }

    public func nextRepetitionCount(in s: String) -> Int {
        let l = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: calendar.locale ?? .current)
        let re = try! NSRegularExpression(pattern: #"(?i)\b(proximo|próximo)(?:\s+proximo|\s+próximo)*\s+semana\b"#)
        if let m = re.firstMatch(in: l, range: NSRange(l.startIndex..., in: l)) {
            let sub = (l as NSString).substring(with: m.range)
            return sub.split(separator: " ").filter({ $0 == "proximo" || $0 == "próximo" }).count
        }
        return phraseIndicatesNext(l) ? 1 : 0
    }

    public func classifyRelativeDay(_ l: String) -> RelativeDay? {
        if l.contains("amanha") || l.contains("amanhã") { return .tomorrow }
        if l.contains("esta noite") || l.contains("hoje a noite") || l.contains("hoje à noite") { return .tonight }
        if l.contains("hoje") { return .today }
        return nil
    }

    public func classifyPartOfDay(_ l: String) -> PartOfDay? {
        if l.contains("manh") { return .morning }
        if l.contains("tarde") { return .afternoon }
        if l.contains("noite") { return .evening }
        if l.contains("meio dia") { return .noon }
        if l.contains("meia noite") { return .midnight }
        return nil
    }
}
