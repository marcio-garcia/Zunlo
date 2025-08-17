//
//  AISuggestion.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

public struct AISuggestion: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let title: String
    public let detail: String
    public let reason: String
    public let ctas: [AISuggestionCTA]
    public let telemetryKey: String
    public let score: Int                     // simple ranking score
}

/// Strategy interface for generating one suggestion from a snapshot.
public protocol AISuggester {
    func suggest(context: AIContext) -> AISuggestion?
}

public protocol AICoolDownSuggester: AISuggester {
    var usage: SuggestionUsageStore { get set }

    /// After a success, we dampen the score and let it recover over this period.
    var cooldown: TimeInterval { get set }      // e.g. 6 hours
    /// Maximum points to subtract right after a success (linearly decays to 0 by cooldown end).
    var maxPenalty: Int { get set }             // e.g. 60
}
