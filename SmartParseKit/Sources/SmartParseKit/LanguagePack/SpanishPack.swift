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
    public var connectorTokens = ["a las", "a", "en", "el", "la", "desde", "hasta", "de", "por", "para"]
    public let weekdayMap: [String : Int]

    public init(calendar: Calendar) {
        var cal = calendar
        cal.locale = Locale(identifier: "es_ES")
        self.calendar = cal
        self.weekdayMap = BaseLanguagePack.makeWeekdayMap(calendar: cal)
    }

    public func weekdayPhraseRegex() -> NSRegularExpression {
        let thisAlt = thisTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let nextAlt = nextTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        return BaseLanguagePack.regex(#"""
        (?ix)\b
        (?:
           ((?:\#(thisAlt))|(?:\#(nextAlt)))\s+
        )?
        (?:el|la)?\s*
        (\#(weekdayAlt))
        (?:\s+que\s+viene)?
        \b
        """#)
    }

    public func weekMainRegex() -> NSRegularExpression {
        let thisAlt = thisTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        let nextAlt = nextTokens.map(NSRegularExpression.escapedPattern).joined(separator: "|")
        return BaseLanguagePack.regex(#"""
        (?ix)\b
        (?:
            (?:\#(thisAlt))\s+semana |
            (?:la\s+)?(?:\#(nextAlt))\s+semana |
            semana\s+que\s+viene
        )
        \b
        """#)
    }

    public func weekBareRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"""
        (?ix)\b(?:
            planificar\s+mi\s+semana |
            planear\s+mi\s+semana   |
            mi\s+semana             |
            agenda\s+de\s+la\s+semana |
            \bsemana\b
        )
        """#)
    }

    public func inlineTimeRangeRegex() -> NSRegularExpression {
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
        let weekdayAlt = BaseLanguagePack.weekdayAlternation(weekdayMap)
        let timeToken  = #"(?:\d{1,2}(?::\d{2})?\s*(?:am|pm|h)?)"#
        return BaseLanguagePack.regex(#"""
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
        """#)
    }

    public func phraseIndicatesNext(_ s: String) -> Bool {
        let l = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: calendar.locale ?? .current)
        return l.contains("proximo")
            || l.contains("proxima")
            || l.contains("siguiente")
            || l.contains("que viene")
            || l.contains("next")
    }

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

    // Intents
    public func intentViewRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?ix)\b(mostrar|ver|mi\s+agenda|agenda|mi\s+calendario|qué\s+hay|que\s+hay)\b"#) }
    public func intentPlanRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?ix)\b(planificar|planear|organizar|estructurar|mapear)\b"#) }
    public func timePivotRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?ix)\b(?:a|a\s+las|de|desde|hasta|por|para)\b"#) }

    // Enhanced create patterns
    public func intentCreateTaskRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(añadir|crear|hacer|configurar|anotar)\s+(?:una?\s+)?(?:nueva?\s+)?(tarea|todo|recordatorio|nota|asignación|elemento\s+de\s+acción|actividad)\b"#)
    }

    public func intentCreateEventRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(programar|agendar|añadir|crear|configurar|reservar)\s+(?:una?\s+)?(?:nueva?\s+)?(reunión|evento|cita|llamada|almuerzo|cena|conferencia|sesión|encuentro)\b"#)
    }

    // Enhanced cancel patterns
    public func intentCancelTaskRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(eliminar|borrar|cancelar|completar|terminar|marcar\s+como\s+completada?|finalizar)\s+(?:la\s+)?(?:esta\s+)?(tarea|todo|recordatorio|nota|actividad|elemento)\b"#)
    }

    public func intentCancelEventRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(cancelar|eliminar|borrar|anular)\s+(?:la\s+)?(?:esta\s+)?(reunión|evento|cita|llamada|almuerzo|cena|conferencia|sesión|encuentro)\b"#)
    }

    // Base intent patterns
    public func intentCreateRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(crear|añadir|programar|agendar|configurar|reservar)\b"#)
    }

    public func intentRescheduleRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(reprogramar|reagendar|posponer|aplazar|retrasar|mover|cambiar|modificar|transferir)\b"#)
    }

    public func intentCancelRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(eliminar|borrar|cancelar|no\s+programar|no\s+agendar|anular)\b"#)
    }

    public func intentUpdateRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(actualizar|editar|modificar|cambiar\s+detalles|alterar)\b"#)
    }

    // Keyword detection
    public func taskKeywordsRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(tarea|todo|recordatorio|nota|asignación|elemento\s+de\s+acción|trabajo|actividad)\b"#)
    }

    public func eventKeywordsRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(reunión|evento|cita|llamada|almuerzo|cena|conferencia|sesión|encuentro|fiesta|ceremonia)\b"#)
    }
    
    // Optionals
    public func weekendRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(?:(?:este|esta|pr[óo]ximo|siguiente|que\s+viene)\s+)?fin\s+de\s+semana\b"#)
    }
    public func relativeDayRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(?:hoy|mañana|manana|esta\s+noche)\b"#)
    }
    public func partOfDayRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(?:(?:por|de|en)\s+la\s+mañana|tarde|noche|mediod[ií]a|medianoche)\b"#)
    }
    public func ordinalDayRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(?:d[ií]a\s+)?([12]?\d|3[01])(?:º|o)?\b"#)
    }
    public func timeOnlyRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(?:mediod[ií]a|medianoche|(?:[01]?\d|2[0-3])(?::\d{2})?\s*(?:h)?(?:\s*(?:am|pm))?)\b"#)
    }
    public func betweenTimeRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b entre \s+ ([0-2]?\d(?::\d{2})?) \s+ (?:y|a|-|hasta) \s+ ([0-2]?\d(?::\d{2})?) \b"#)
    }
    public func inFromNowRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(?:en|dentro\s+de)\s+(\d+)\s+(minutos?|mins?|horas?|hrs?|d[ií]as?|semanas?|mes(?:es)?)\b"#)
    }
    public func byOffsetRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(?:en|por)\s+(\d+)\s+(minutos?|mins?|horas?|hrs?|d[ií]as?|semanas?|mes(?:es)?)\b"#)
    }

    public func nextRepetitionCount(in s: String) -> Int {
        let l = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: calendar.locale ?? .current)
        let re = try! NSRegularExpression(pattern: #"(?i)\b(pr[óo]ximo)(?:\s+pr[óo]ximo)*\s+semana\b"#)
        if let m = re.firstMatch(in: l, range: NSRange(l.startIndex..., in: l)) {
            let sub = (l as NSString).substring(with: m.range)
            return sub.split(separator: " ").filter({ $0 == "proximo" || $0 == "próximo" }).count
        }
        return phraseIndicatesNext(l) ? 1 : 0
    }

    public func classifyRelativeDay(_ s: String) -> RelativeDay? {
        let l = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: calendar.locale ?? .current)
        if l.contains("mañana") || l.contains("manana") { return .tomorrow }
        if l.contains("esta noche") { return .tonight }
        if l.contains("hoy") { return .today }
        return nil
    }
    public func classifyPartOfDay(_ s: String) -> PartOfDay? {
        let l = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: calendar.locale ?? .current)
        if l.contains("por la mañana") || l.contains("de la mañana") || l.contains("en la mañana") || l.contains("mañana") || l.contains("manana") { return .morning }
        if l.contains("tarde") { return .afternoon }
        if l.contains("noche") { return .evening }
        if l.contains("mediodia") || l.contains("mediodía") { return .noon }
        if l.contains("medianoche") { return .midnight }
        return nil
    }
}
