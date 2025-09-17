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
    public var connectorTokens = ["às","as","a","à","na","o","os","no","em","de","das","até","ate","ao","pela","pelas","pelo","pelos","para","pra","pras"]
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
    public func intentViewRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(mostr\S+|ver|minha\s+agenda|agenda|meu\s+calend[aá]rio|calendario|o\s+que\s+(h[aá]|tem))\b"#)
    }
    public func intentPlanRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(planejar|organizar|estruturar|mapear)\b"#)
    }
    public func timePivotRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(?:às|as|a|pra|pras|para|das|de|desde|at[eé])\b"#)
    }
    
    // Enhanced create patterns
    public func intentCreateTaskRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(adicionar|criar|fazer|configurar|marcar)\s+(?:uma?\s+)?(?:nova?\s+)?.*\b"#)
    }

    public func intentCreateEventRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"\b(agendar|agende|marcar|marque|adicion\S+|cri\S+|configur\S+|program\S+|bloqu\S+)\s+(?:uma?\s+)?(?:nova?\s+)?.*\b"#)
    }

    // Enhanced cancel patterns
    public func intentCancelTaskRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(deletar|remover|cancelar|completar|finalizar|marcar\s+como\s+concluída?|concluir)\s+(?:a\s+)?(?:esta\s+)?.*\b"#)
    }

    public func intentCancelEventRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(cancelar|deletar|remover|desmarcar)\s+(?:a\s+)?(?:esta\s+)?.*\b"#)
    }

    // Base intent patterns
    public func intentCreateRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(criar|adicionar|agendar|marcar|configurar|programar)\b"#)
    }

    public func intentRescheduleRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(reagend\S+|remar\S+|adi\S+|empurr\S+|atras\S+|mov\S+|mud\S+|modifi\S+|transf\S+)\b"#)
    }

    public func intentCancelRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(delet\S+|remov\S+|cancel\S+|não\s+agend\S+|não\s+marcar|desmar\S+)\b"#)
    }

    public func intentUpdateRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"\b(atualiz\S+|edit\S+|modifi\S+|mud\S+\s+detalhes|alter\S+|renom\S+)\b"#)
    }

    // Keyword detection
    public func taskKeywordsRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(tarefa|todo|afazer|lembrete|nota|atividade)\b"#)
    }

    public func eventKeywordsRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(evento)\b"#)
    }

    // Metadata addition detection patterns
    public func metadataAdditionWithPrepositionRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"\b(adicionar|adicione|definir|defina|colocar|coloque)\s+((tag|prioridade|lembrete|nota|local|localização)(:)?\s+)(\S+)?((para|na|no|à|ao|da|do)\s+)?\b"#)
    }

    public func metadataAdditionDirectRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(adicionar|adicione|definir|defina|colocar|coloque)\s+(tag|prioridade|lembrete|nota|local|localização)\s+\S+.*\b.*?\b"#)
    }

    public func taskEventReferenceRegex() -> NSRegularExpression {
        BaseLanguagePack.regex(#"(?ix)\b(tarefa|evento|reunião|compromisso|item|atividade)\b"#)
    }
    
    public func weekendRegex() -> NSRegularExpression? { BaseLanguagePack.regex(#"(?ix)\b(?:(?:este|esta|proximo|próximo|seguinte)\s+)?fim\s*de\s*semana\b"#) }
    public func relativeDayRegex() -> NSRegularExpression? { BaseLanguagePack.regex(#"(?ix)\b(?:hoje|amanh[ãa]|esta\s+noite)\b"#) }
    public func partOfDayRegex() -> NSRegularExpression? { BaseLanguagePack.regex(#"(?ix)\b(?:manh[ãa]|tarde|noite|meio\s*dia|meia\s*noite)\b"#) }
    public func ordinalDayRegex() -> NSRegularExpression? { BaseLanguagePack.regex(#"(?ix)\b(?:dia\s*)?([12]?\d|3[01])(?:º|ª|o)?\b"#) }
    public func timeOnlyRegex() -> NSRegularExpression? {
        return BaseLanguagePack.regex(#"\b(?:meio(?:-|\s*)dia|meia(?:-|\s*)noite|\#(BaseLanguagePack.timeToken))\b"#)
    }
    public func betweenTimeRegex() -> NSRegularExpression? {
        return BaseLanguagePack.regex(#"(?ix)\b entre \s+ (\#(BaseLanguagePack.timeToken)) \s+ (?:e|-|a|até) \s+ (\#(BaseLanguagePack.timeToken)) \b"#)
    }
    public func inFromNowRegex() -> NSRegularExpression? { BaseLanguagePack.regex(#"(?ix)\b(?:em|dentro\s+de)\s+(\d+)\s+(minutos?|mins?|horas?|hrs?|dias?|semanas?|meses?)\b"#) }
    public func articleFromNowRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"(?ix)\b(?:daqui\s+a\s+)?(uma?|um)\s+(minuto|hora|dia|semana|mês|ano)s?(?:\s+a\s+partir\s+de\s+agora)?\b"#)
    }
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

    // MARK: - Metadata Pattern Implementation

    public func tagPatternRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"""
        (?ix)
        \b(?:adicionar\s+)?(?:com\s+)?(?:tag|etiqueta)\s+([a-zA-Z0-9_-]+)(?:\s+(?:para|em))?\b
        |
        \b(?:tags?|etiquetas?)\s*[:=]\s*([a-zA-Z0-9_,-]+)\b
        |
        \b(?:marcado\s+(?:como\s+)?|rotulo(?:ado)?\s+(?:como\s+)?|categoria\s+)([a-zA-Z0-9_-]+)\b
        """#) // groups 1, 2, or 3 = tag name(s)
    }

    public func reminderPatternRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"""
        (?ix)
        \b(?:me\s+lembrar|lembrete\s+(?:em|para|às)|alerta\s+em|adicion\S+\s+lembr\S+|adicion\S+\s+alerta|adicion\S+\s+aviso)
        (?:\s+(?:em|às|para))?\s+
        (?:(\d+)\s+(minutos?|mins?|horas?|hrs?|dias?)\s+(?:antes|de\s+antecedencia)
        |(?:às\s+)?(\d{1,2}(?::\d{2})?)(?:\s*[hH])?
        |(\d+)\s+(minutos?|mins?|horas?|hrs?|dias?))\b
        """#) // groups: 1=number, 2=unit, 3=time, 4=offset_number, 5=offset_unit
    }

    public func priorityPatternRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"""
        (?ix)
        \b(?:(?:definir\s+)?prioridade\s+(?:como\s+|para\s+)?
        |(?:marcar\s+(?:como\s+)?)?(?:prioridade\s+)?)
        (urgente|alta|media|média|normal|baixa|crítica|critica|importante)
        (?:\s+prioridade)?\b
        |
        \b(urgente|alta|media|média|normal|baixa|crítica|critica|importante)(?:\s+prioridade)?\b
        """#) // groups 1 or 2 = priority level
    }

    public func locationPatternRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"""
        (?ix)
        \b(?:em|na|no|local\s*[:=]?)\s+
        (?:o|a|os|as\s+)?([a-zA-ZÀ-ÿ0-9\s_-]{2,50}?)
        (?=\s+(?:amanhã|hoje|ontem|próximo|próxima|na|no|em|para|com|às?|\d|$)|[.!?,:;]|$)
        |
        \blocal\s*[:=]\s*([a-zA-ZÀ-ÿ0-9\s_-]{2,50})
        """#) // groups 1 or 2 = location name
    }

    public func notesPatternRegex() -> NSRegularExpression? {
        BaseLanguagePack.regex(#"""
        (?ix)
        \b(?:notas?|comentários?|comentarios?|descrição|descricao)
        \s*[:=]\s*
        ([^.!?;]{1,200})
        (?=[.!?;]|$)
        """#) // group 1 = notes content
    }

    public func classifyPriority(_ matchedLowercased: String) -> TaskPriority? {
        let text = matchedLowercased.lowercased()
        if text.contains("urgente") || text.contains("crítica") || text.contains("critica") {
            return .urgent
        } else if text.contains("alta") || text.contains("importante") {
            return .high
        } else if text.contains("média") || text.contains("media") || text.contains("normal") {
            return .medium
        } else if text.contains("baixa") {
            return .low
        }
        return nil
    }

    public func extractReminderOffset(_ matchedText: String) -> TimeInterval? {
        let text = matchedText.lowercased()
        let regex = try? NSRegularExpression(pattern: #"(\d+)\s+(minutos?|mins?|horas?|hrs?|dias?)"#, options: .caseInsensitive)

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
        case let u where u.hasPrefix("hora") || u.hasPrefix("hr"):
            return number * 3600
        case let u where u.hasPrefix("dia"):
            return number * 86400
        default:
            return nil
        }
    }
}
