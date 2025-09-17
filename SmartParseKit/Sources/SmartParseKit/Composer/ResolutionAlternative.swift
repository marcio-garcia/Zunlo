//
//  ResolutionAlternative.swift
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

public enum MatchSource: String, Equatable {
    case appleDetector      // NSDataDetector
    case nextWeekdayOverride // configurable "next friday" to be treated like next friday or the friday of the next week
    case inlineWeekdayTime  // “fri 9-10”, “sex 11-1”, “wed 9”
    case fromToTime         // “de 10 a 12”, “from 9 to 10”
    case weekPhrase         // “esta semana”, “next week”, bare “week”
    case other
}
