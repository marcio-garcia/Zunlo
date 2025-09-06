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

/// Normalized summary for UI/analytics.
public struct RelativePhraseResolution: Equatable {
    public let text: String                     // substring that matched
    public let range: Range<String.Index>

    public let modifier: RelativeModifier       // this / next / none
    public let weekday: Int?                    // 1...7 if applicable (Sunday = 1)
    public let originalDate: Date               // Apple/NSDataDetector date
    public let resolvedDate: Date               // After our “human” override (or same)
    public let overridden: Bool                 // Did we override Apple’s date?
    public let deltaDays: Int                   // signed day difference: resolved - original
    public let timeZone: TimeZone?
    public let duration: TimeInterval?

    /// Suggest showing a confirm UI if we moved it ≥ 6 days (typical "skip-a-week" fix).
    public var needsConfirmation: Bool {
        abs(deltaDays) >= 6
    }

    /// Short explanation for UI surfaces.
    public func reason(calendar: Calendar = .current) -> String {
        guard overridden else { return "Mantido conforme detectado" }
        switch modifier {
        case .this:
            return "Interpretado como “este \(weekdayName(calendar: calendar))” (próxima ocorrência)"
        case .next:
            return deltaDays >= 6
                ? "Interpretado como “próximo \(weekdayName(calendar: calendar))” (sem pular uma semana)"
                : "Interpretado como “próximo \(weekdayName(calendar: calendar))”"
        case .none:
            return "Ajuste aplicado ao dia da semana detectado"
        }
    }

    public func weekdayName(calendar: Calendar = .current) -> String {
        guard let w = weekday else { return "" }
        let names = calendar.weekdaySymbols
        return names[w - 1].lowercased()
    }
}

public extension HumanDateDetector {
    /// Runs `matches(in:)` and returns normalized summaries suitable for UI.
    func normalizedResolutions(in text: String, base: Date = Date()) -> [RelativePhraseResolution] {
        let all = matches(in: text, base: base)
        return all.compactMap { m in
            guard let originalDate = m.original.date else { return nil }
            let substr = String(text[m.range])
            // Re-run the small relative-phrase detection to extract modifier/weekday.
            let phrase = substr.lowercased()
            let (modifier, weekday) = extractModifierAndWeekday(from: phrase)
            let delta = daysBetween(originalDate, m.date)

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
                duration: m.duration
            )
        }
    }

    // MARK: - Helpers for normalized summaries

    internal func extractModifierAndWeekday(from phrase: String) -> (RelativeModifier, Int?) {
        let ns = phrase as NSString
        let range = NSRange(location: 0, length: ns.length)

        // Try main pattern first (captures modifier + weekday)
        if let m = regex.firstMatch(in: phrase, options: [], range: range) {
            let modTok = substring(phrase, m.range(at: 1))
            let weekdayStr = substring(phrase, m.range(at: 2))
            let modifier: RelativeModifier = matchesAny(modTok, in: lexicon.thisWords) ? .this : .next
            let weekday = lexicon.weekdayToNumber[weekdayStr]
            return (modifier, weekday)
        }

        // Try "<weekday> que vem" (implicit NEXT)
        if let m2 = weekdayQueVemRegex.firstMatch(in: phrase, options: [], range: range) {
            let weekdayStr = substring(phrase, m2.range(at: 1))
            let weekday = lexicon.weekdayToNumber[weekdayStr]
            return (.next, weekday)
        }

        return (.none, nil)
    }

    internal func daysBetween(_ a: Date, _ b: Date) -> Int {
        let startA = calendar.startOfDay(for: a)
        let startB = calendar.startOfDay(for: b)
        let comps = calendar.dateComponents([.day], from: startA, to: startB)
        return comps.day ?? 0
    }
}
