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
    
    /// Relative weekday phrases.
    /// Capturing groups MUST be:
    ///   (1) optional modifier token (may be NSNotFound/empty)
    ///   (2) weekday token (must map via lexicon.weekdayToNumber)
    func weekdayPhraseRegex() -> NSRegularExpression

    /// “This/next week” phrases.
    func weekMainRegex() -> NSRegularExpression

    /// Bare “week” cues (plan my week / minha semana …).
    func weekBareRegex() -> NSRegularExpression

    /// Inline “<weekday> <time>[-<time>]”.
    /// Group 1: weekday, Group 2: start time, Group 3: optional end time.
    func inlineTimeRangeRegex() -> NSRegularExpression

    /// “From–to” with optional weekday.
    /// Groups: (1) optional weekday, (2) start time, (3) end time.
    func fromToTimeRegex() -> NSRegularExpression

    /// Whether a phrase implies “next” (used for week phrases).
    func phraseIndicatesNext(_ phraseLowercased: String) -> Bool
    
    // NEW: boilerplate command/intents to remove from the beginning of titles
    func commandPrefixRegex() -> NSRegularExpression
}

// MARK: - Base helper (weekday maps + regex builder)

public enum BaseLanguagePack {
    public static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .allowCommentsAndWhitespace])
    }

    public static func weekdayAlternation(_ map: [String: Int]) -> String {
        map.keys
            .sorted { $0.count > $1.count } // prefer longer first
            .map(NSRegularExpression.escapedPattern)
            .joined(separator: "|")
    }

    /// Build a resilient weekday map from the calendar’s locale,
    /// plus ALWAYS add EN 3-letter aliases (sun…sat).
    public static func makeWeekdayMap(calendar: Calendar) -> [String: Int] {
        var map: [String: Int] = [:]
        var cal = calendar
        let loc = cal.locale ?? .current
        cal.locale = loc

        let full  = cal.weekdaySymbols.map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: loc).lowercased() }
        let short = cal.shortWeekdaySymbols.map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: loc).lowercased().replacingOccurrences(of: ".", with: "") }
        let very  = cal.veryShortWeekdaySymbols.map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: loc).lowercased() }

        for w in 1...7 {
            let f = full[w-1], s = short[w-1], v = very[w-1]
            map[f] = w; map[s] = w; map[v] = w

            // For languages with hyphen (e.g., "segunda-feira")
            let noHyphen = f.replacingOccurrences(of: "-", with: " ")
            if noHyphen != f { map[noHyphen] = w }

            // PT shorthands (segunda/terça/quarta/quinta/sexta)
            if f.contains("segunda") { map["segunda"] = w }
            if f.contains("terca") || f.contains("terça") { map["terca"] = w; map["terça"] = w }
            if f.contains("quarta") { map["quarta"] = w }
            if f.contains("quinta") { map["quinta"] = w }
            if f.contains("sexta")  { map["sexta"]  = w }
        }

        // ALWAYS add English 3-letter aliases (sun..sat)
        let en3 = ["sun","mon","tue","wed","thu","fri","sat"]
        for (i, key) in en3.enumerated() { map[key] = i+1 }

        return map
    }
}
