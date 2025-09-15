//
//  DateLanguagePack.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/8/25.
//

import Foundation

// MARK: - Language pack protocol

public protocol DateLanguagePack {
    var calendar: Calendar { get }          // preconfigured with locale/tz if you want
    var thisTokens: [String] { get }        // e.g. ["this", "coming"] / ["este", "esta"]
    var nextTokens: [String] { get }        // e.g. ["next"] / ["próximo", "que vem"]
    var weekdayMap: [String: Int] { get }   // lowercased tokens → 1…7 (Sun=1)
    var connectorTokens: [String] { get }   // tokens to strip when extracting titles

    func weekdayPhraseRegex() -> NSRegularExpression
    func weekMainRegex() -> NSRegularExpression
    func weekBareRegex() -> NSRegularExpression
    func inlineTimeRangeRegex() -> NSRegularExpression
    func fromToTimeRegex() -> NSRegularExpression
    func phraseIndicatesNext(_ phraseLowercased: String) -> Bool
    func commandPrefixRegex() -> [NSRegularExpression]

    // Intent regexes
    func intentCreateRegex() -> NSRegularExpression
    func intentRescheduleRegex() -> NSRegularExpression
    func intentCancelRegex() -> NSRegularExpression
    func intentViewRegex() -> NSRegularExpression
    func intentPlanRegex() -> NSRegularExpression

    func intentCreateTaskRegex() -> NSRegularExpression
    func intentCreateEventRegex() -> NSRegularExpression
    func intentCancelTaskRegex() -> NSRegularExpression
    func intentCancelEventRegex() -> NSRegularExpression
    func intentUpdateRegex() -> NSRegularExpression
    func taskKeywordsRegex() -> NSRegularExpression

    // Metadata addition detection patterns
    func metadataAdditionWithPrepositionRegex() -> NSRegularExpression
    func metadataAdditionDirectRegex() -> NSRegularExpression
    func taskEventReferenceRegex() -> NSRegularExpression
    func eventKeywordsRegex() -> NSRegularExpression
    
    // Pivot used to prefer the rightmost time after these tokens
    func timePivotRegex() -> NSRegularExpression

    // Optional detectors (default nil). Packs may override.
    func weekendRegex() -> NSRegularExpression?
    func relativeDayRegex() -> NSRegularExpression?
    func partOfDayRegex() -> NSRegularExpression?
    func ordinalDayRegex() -> NSRegularExpression?
    func timeOnlyRegex() -> NSRegularExpression?
    func betweenTimeRegex() -> NSRegularExpression?
    func inFromNowRegex() -> NSRegularExpression?
    func articleFromNowRegex() -> NSRegularExpression?
    func byOffsetRegex() -> NSRegularExpression?

    // Language-aware classification helpers
    func classifyRelativeDay(_ matchedLowercased: String) -> RelativeDay?
    func classifyPartOfDay(_ matchedLowercased: String) -> PartOfDay?

    // Count repetitions for "next next week". Default uses phraseIndicatesNext.
    func nextRepetitionCount(in phrase: String) -> Int

    // MARK: - Metadata Detection Patterns

    // Tag patterns: "tag work", "add tag home to", "with tag personal"
    func tagPatternRegex() -> NSRegularExpression?

    // Reminder patterns: "remind me 30 minutes before", "set reminder for", "alert at"
    func reminderPatternRegex() -> NSRegularExpression?

    // Priority patterns: "high priority", "urgent", "low importance"
    func priorityPatternRegex() -> NSRegularExpression?

    // Location patterns: "at home", "location office", "in the kitchen"
    func locationPatternRegex() -> NSRegularExpression?

    // Notes patterns: "note:", "notes:", "comment:", "description:"
    func notesPatternRegex() -> NSRegularExpression?

    // Helper to classify priority from matched text
    func classifyPriority(_ matchedLowercased: String) -> TaskPriority?

    // Helper to extract reminder time offset from matched text
    func extractReminderOffset(_ matchedText: String) -> TimeInterval?
}

//public extension DateLanguagePack {
//    func weekendRegex() -> NSRegularExpression? { nil }
//    func relativeDayRegex() -> NSRegularExpression? { nil }
//    func partOfDayRegex() -> NSRegularExpression? { nil }
//    func ordinalDayRegex() -> NSRegularExpression? { nil }
//    func timeOnlyRegex() -> NSRegularExpression? { nil }
//    func betweenTimeRegex() -> NSRegularExpression? { nil }
//    func inFromNowRegex() -> NSRegularExpression? { nil }
//    func articleFromNowRegex() -> NSRegularExpression? { nil }
//    func byOffsetRegex() -> NSRegularExpression? { nil }
//    func classifyRelativeDay(_ s: String) -> RelativeDay? { nil }
//    func classifyPartOfDay(_ s: String) -> PartOfDay? { nil }
//    func nextRepetitionCount(in phrase: String) -> Int { phraseIndicatesNext(phrase) ? 1 : 0 }
//
//    func intentCreateRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?i)\b(create|add|schedule|book|set\s*up)\b"#) }
//    func intentRescheduleRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?i)\b(reschedul|rebook|postpone|push\s*back|delay|move|change|modify)\b"#) }
//    func intentCancelRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?i)\b(delete|remove|cancel|don't\s+schedule|do\s+not\s+schedule)\b"#) }
//    func intentViewRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?i)\b(show|view|what's\s+on|agenda|my\s+schedule)\b"#) }
//    func intentPlanRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?i)\b(plan|organize|structure|map\s+out)\b"#) }
//    func timePivotRegex() -> NSRegularExpression { BaseLanguagePack.regex(#"(?i)\b(?:at|to)\b"#) }
//}

// MARK: - Base helper (weekday maps + regex builder)

public enum BaseLanguagePack {
    public static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .allowCommentsAndWhitespace])
    }

    public static func weekdayAlternation(_ map: [String: Int]) -> String {
        map.keys
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern)
            .joined(separator: "|")
    }

    /// Robust weekday map builder using DateFormatter (not Calendar.*Symbols).
    /// Sun=1 … Sat=7, with locale/diacritics normalized.
    public static func makeWeekdayMap(calendar: Calendar) -> [String: Int] {
        var map: [String: Int] = [:]
        var cal = calendar
        let loc = cal.locale ?? .current
        cal.locale = loc

        let fmt = DateFormatter()
        fmt.locale = loc
        fmt.calendar = cal
        // Standalone context tends to produce the “dictionary” forms (e.g., “Monday”)
        fmt.formattingContext = .standalone

        // Prefer DateFormatter symbols (more reliable than Calendar.*Symbols)
        let full  = fmt.weekdaySymbols
        let short = fmt.shortWeekdaySymbols
        let very  = fmt.veryShortWeekdaySymbols

        func norm(_ s: String) -> String {
            s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: loc)
             .lowercased()
             .replacingOccurrences(of: ".", with: "")
        }

        // Map: 1…7 (Sun=1)
        for w in 1...7 {
            let f = norm(full![w-1])
            let s = norm(short![w-1])
            let v = norm(very![w-1])

            map[f] = w
            map[s] = w
            map[v] = w

            // Hyphen → space (e.g., “segunda-feira”)
            let noHyphen = f.replacingOccurrences(of: "-", with: " ")
            if noHyphen != f { map[noHyphen] = w }

            // PT shorthands (segunda/terça/quarta/quinta/sexta)
            if f.contains("segunda") { map["segunda"] = w }
            if f.contains("terca") || f.contains("terça") { map["terca"] = w; map["terça"] = w }
            if f.contains("quarta") { map["quarta"] = w }
            if f.contains("quinta") { map["quinta"] = w }
            if f.contains("sexta")  { map["sexta"]  = w }
        }

        // Safety: ALWAYS add English aliases (helps mixed-language input)
        let en3   = ["sun","mon","tue","wed","thu","fri","sat"]
        let enFull = ["sunday","monday","tuesday","wednesday","thursday","friday","saturday"]
        for (i, k) in en3.enumerated()   { map[k] = i+1 }
        for (i, k) in enFull.enumerated(){ map[k] = i+1 }

        return map
    }

    // Accepts 09:30, 9, 9am, 21h, 21h30, 21 hs, 21 hrs
    public static var timeToken: String {
        return #"(?:(?:[01]?[0-9]|2[0-3])(?::[0-5][0-9])?(?:\s*[h]\s*[0-5][0-9])?)\s*(?:am|pm|h(?:r)?s?)?"#
    }
}
