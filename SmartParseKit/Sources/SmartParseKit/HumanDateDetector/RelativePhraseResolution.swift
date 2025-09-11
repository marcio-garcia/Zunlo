//
//  RelativePhraseResolution.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/6/25.
//

import Foundation

/// Modifier detected or inferred from the phrase.
public enum RelativeModifier: String {
    case this
    case next
    case none // explicit dates or phrases with no relative modifier
}

public struct ResolutionAlternative: Equatable {
    public let date: Date
    public let duration: TimeInterval?
    public let source: MatchSource
    /// Optional short label for UI chips (“sex às 9h”, “dia 9 (ter)”).
    public let label: String?
}

/// Normalized summary for UI/analytics.
public struct RelativePhraseResolution: Equatable {
    public let text: String                     // substring that matched
    public let range: Range<String.Index>
    public let modifier: RelativeModifier       // this / next / none
    public let weekday: Int?                    // 1...7 if applicable (Sunday = 1)
    public let originalDate: Date               // Apple/NSDataDetector date (or same as resolved if synthetic)
    public let resolvedDate: Date               // After our “human” override (or same)
    public let overridden: Bool                 // Did we override Apple’s date or synthesize a week?
    public let deltaDays: Int                   // signed day difference: resolved - original
    public let timeZone: TimeZone?
    public let duration: TimeInterval?          // week phrases set this to ~7d
    public let isWeekPhrase: Bool               // explicitly tag week phrases
    public let ambiguous: Bool
    public let ambiguityReason: String?
    public let alternatives: [ResolutionAlternative] // competing interpretations (including this one, if you like)
    
    /// Suggest showing a confirm UI if we moved it ≥ 6 days (typical "skip-a-week" fix).
    public var needsConfirmation: Bool { abs(deltaDays) >= 6 }

    // MARK: - Localized reason

    /// Returns a short, localized explanation for UI surfaces.
    /// - Parameters:
    ///   - calendar: Calendar used for weekday names.
    ///   - locale:   Preferred locale for messages (falls back to `calendar.locale` or `.current`).
    public func reason(calendar: Calendar = .current, locale: Locale? = nil) -> String {
        let loc = locale ?? calendar.locale ?? Locale.current
        let lang = (loc.language.languageCode?.identifier.lowercased())
            ?? (loc.language.languageCode?.identifier.lowercased()) // iOS older API compatibility
            ?? loc.identifier.lowercased()

        // Helpers for i18n strings:
        func localized(_ ptBR: String, _ en: String, _ es: String? = nil) -> String {
            if lang.hasPrefix("pt") { return ptBR }
            if lang.hasPrefix("es"), let es = es { return es }
            return en
        }

        if ambiguous {
            return "Ambíguo: \(ambiguityReason ?? "horário pouco claro")"
        }
        
        // If nothing was overridden, say so
        if !overridden {
            return localized("Mantido conforme detectado",
                             "Kept as detected",
                             "Mantenido según lo detectado")
        }

        // Week phrases
        if isWeekPhrase {
            switch modifier {
            case .next:
                return localized("Intervalo interpretado como “próxima semana”",
                                 "Interpreted as “next week”",
                                 "Interpretado como “la próxima semana”")
            case .this, .none:
                return localized("Intervalo interpretado como “esta semana”",
                                 "Interpreted as “this week”",
                                 "Interpretado como “esta semana”")
            }
        }

        // Weekday phrases
        let wname = weekdayName(calendar: calendar, locale: loc)
        switch modifier {
        case .this:
            return localized(
                "Interpretado como “este \(wname)” (próxima ocorrência)",
                "Interpreted as “this \(wname)” (next occurrence)",
                "Interpretado como “este \(wname)” (próxima ocurrencia)"
            )
        case .next:
            if deltaDays >= 6 {
                return localized(
                    "Interpretado como “próximo \(wname)” (sem pular uma semana)",
                    "Interpreted as “next \(wname)” (without skipping a week)",
                    "Interpretado como “próximo \(wname)” (sin saltar una semana)"
                )
            } else {
                return localized(
                    "Interpretado como “próximo \(wname)”",
                    "Interpreted as “next \(wname)”",
                    "Interpretado como “próximo \(wname)”"
                )
            }
        case .none:
            return localized(
                "Ajuste aplicado ao dia da semana detectado",
                "Adjusted the detected weekday",
                "Ajuste aplicado al día de la semana detectado"
            )
        }
    }

    /// Localized, lowercase weekday name for the stored `weekday` (1=Sunday … 7=Saturday).
    /// Falls back to the calendar’s own symbols and current locale if needed.
    public func weekdayName(calendar: Calendar = .current, locale: Locale? = nil) -> String {
        guard let w = weekday else { return "" }
        var cal = calendar
        if let loc = locale ?? calendar.locale ?? Locale.current as Locale? {
            cal.locale = loc
        }
        // Use a DateComponents to safely extract name from calendar’s localized symbols
        let names = cal.weekdaySymbols
        guard (1...7).contains(w), w-1 < names.count else { return "" }
        return names[w - 1].lowercased()
    }
}


public extension HumanDateDetector {
    /// Runs `matches(in:)` and returns normalized summaries suitable for UI,
    /// attaching alternative interpretations when multiple matches overlap.
    func normalizedResolutions(in text: String, base: Date = Date()) -> [RelativePhraseResolution] {
        let all = matches(in: text, base: base)

        // Precompute overlap groups by index
        // Simple O(n^2) pass is fine for short utterances
        func overlaps(_ a: Match, _ b: Match) -> Bool {
            let na = NSRange(a.range, in: text)
            let nb = NSRange(b.range, in: text)
            return NSIntersectionRange(na, nb).length > 0
        }

        // Helper to label a candidate for UI
        func makeLabel(_ date: Date, _ dur: TimeInterval?, cal: Calendar) -> String {
            let df = DateFormatter()
            df.calendar = cal
            df.locale = cal.locale
            df.timeZone = cal.timeZone
            df.dateStyle = .medium
            df.timeStyle = (dur == nil || dur == 0) ? .short : .short
            return df.string(from: date)
        }

        // Build rows
        let result = all.map { m in
            let substr = String(text[m.range])
            let originalDate = m.original?.date ?? m.date

            // Re-detect modifier/weekday/week-phrase using your packs
            let (modifier, weekday, isWeekPhrase) = extractModifierWeekdayOrWeek(in: text, around: m.range)

            let delta = daysBetween(originalDate, m.date)

            // Collect overlapping candidates as alternatives (distinct by date/duration/source)
            let group = all.filter { overlaps(m, $0) }
            var alts: [ResolutionAlternative] = []
            var seen = Set<String>()
            for g in group {
                let key = "\(g.date.timeIntervalSinceReferenceDate)|\(g.duration ?? -1)|\(g.source.rawValue)"
                if seen.insert(key).inserted {
                    alts.append(ResolutionAlternative(
                        date: g.date,
                        duration: g.duration,
                        source: g.source,
                        label: makeLabel(g.date, g.duration, cal: calendar)
                    ))
                }
            }

            return RelativePhraseResolution(
                text: substr,
                range: m.range,
                modifier: modifier,
                weekday: weekday,
                originalDate: originalDate,
                resolvedDate: m.date,
                overridden: m.overridden,
                deltaDays: delta,
                timeZone: m.timeZone,
                duration: m.duration,
                isWeekPhrase: isWeekPhrase,
                ambiguous: m.ambiguous,
                ambiguityReason: m.ambiguityReason,
                alternatives: alts
            )
        }
        
        return result
    }

    // MARK: - Modifier/weekday extraction with context window

    /// Tries to infer modifier/weekday/week-phrase using a context window around the match,
    /// so phrases like "next Sunday at 10am" are correctly read even if `phrase == "Sunday at 10am"`.
    internal func extractModifierWeekdayOrWeek(
        in fullText: String,
        around matchRange: Range<String.Index>,
        leftWindow: Int = 24,
        rightWindow: Int = 16
    ) -> (RelativeModifier, Int?, Bool) {

        // Expand bounds safely
        let start = fullText.index(matchRange.lowerBound, offsetBy: -leftWindow, limitedBy: fullText.startIndex) ?? fullText.startIndex
        let end   = fullText.index(matchRange.upperBound, offsetBy:  rightWindow, limitedBy: fullText.endIndex)  ?? fullText.endIndex
        let windowRange = start..<end
        let window = String(fullText[windowRange])

        // Try detection within the window; if we still can't find a modifier,
        // fall back to the clipped phrase only.
        let (mod, wday, isWeek) = extractModifierWeekdayOrWeek(from: window)
        if mod != .none || wday != nil || isWeek { return (mod, wday, isWeek) }

        // Fallback to just the clipped phrase
        let clipped = String(fullText[matchRange])
        return extractModifierWeekdayOrWeek(from: clipped)
    }

    /// Tries every installed language pack to infer:
    /// - a relative modifier (`this` / `next` / `none`)
    /// - a weekday number (1=Sun … 7=Sat) if present
    /// - whether the phrase is a week interval phrase
    internal func extractModifierWeekdayOrWeek(from phrase: String) -> (RelativeModifier, Int?, Bool) {
        // Iterate all language bundles; return the first that hits
        let ns = phrase as NSString
        let range = NSRange(location: 0, length: ns.length)

        for b in bundles {
            // 1) Modifier + weekday (bundle-specific regex)
            if let m = b.weekday.firstMatch(in: phrase, options: [], range: range) {
                // Safely get a modifier token if the group exists
                let modTok: String = {
                    let g1 = m.range(at: 1)
                    guard g1.location != NSNotFound, g1.length > 0 else { return "" }
                    return substring(phrase, g1)
                }()

                // Find the captured group that corresponds to a weekday by consulting the pack's map.
                // This is safer than assuming a fixed group index.
                var weekdayNum: Int?
                if m.numberOfRanges > 1 {
                    for i in 1..<m.numberOfRanges {
                        let gr = m.range(at: i)
                        if gr.location == NSNotFound || gr.length == 0 { continue }
                        let cand = substring(phrase, gr).lowercased()
                        if let w = b.pack.weekdayMap[cand] {
                            weekdayNum = w
                            break
                        }
                    }
                }

                // Determine modifier:
                //  - If we have an explicit token, match against this/next lists.
                //  - Else, infer "next" from the full phrase (e.g., "que vem", "que viene", "next").
                var modifier: RelativeModifier = .none
                if !modTok.isEmpty {
                    let modFold = modTok.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                                 locale: b.pack.calendar.locale ?? .current)
                    if b.pack.thisTokens.contains(where: {
                        modFold.contains($0.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                                    locale: b.pack.calendar.locale ?? .current))
                    }) {
                        modifier = .this
                    } else if b.pack.nextTokens.contains(where: {
                        modFold.contains($0.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                                    locale: b.pack.calendar.locale ?? .current))
                    }) {
                        modifier = .next
                    }
                } else if b.pack.phraseIndicatesNext(phrase) {
                    // e.g., "domingo que vem" / "domingo que viene" / "... next ..."
                    modifier = .next
                }

                return (modifier, weekdayNum, false)
            }

            // 2) Week phrases (explicit "this/next week" OR bare "week" cues)
            if b.weekMain.firstMatch(in: phrase, options: [], range: range) != nil {
                let isNext = b.pack.phraseIndicatesNext(phrase)
                return (isNext ? .next : .this, nil, true)
            }
            if b.weekBare.firstMatch(in: phrase, options: [], range: range) != nil {
                return (.this, nil, true)
            }
        }

        return (.none, nil, false)
    }

    internal func daysBetween(_ a: Date, _ b: Date) -> Int {
        let startA = calendar.startOfDay(for: a)
        let startB = calendar.startOfDay(for: b)
        let comps = calendar.dateComponents([.day], from: startA, to: startB)
        return comps.day ?? 0
    }
}
