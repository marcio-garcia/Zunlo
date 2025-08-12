//
//  SuggestionOrchestrator.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

// =====================================================
// MARK: - Orchestrator (ranking + cooldown gate)
// =====================================================

import Foundation

@MainActor
public struct SuggestionOrchestrator {
    public var suggesters: [AISuggester]
    public var minScore: Int = 60
    public var perSessionLimit: Int = 3
    public var cooldown: TimeInterval = 30 * 60 // 30 minutes

    /// telemetryKey -> last accepted/acted time (inject from telemetry store)
    public var cooldowns: [String: Date] = [:]

    public init(_ suggesters: [AISuggester]) {
        self.suggesters = suggesters
    }

    public func run(context: AIContext) -> [AISuggestion] {
        var out: [AISuggestion] = []

        for s in suggesters {
            guard var sug = s.suggest(context: context) else { continue }
            guard sug.score >= minScore else { continue }

            if let last = cooldowns[sug.telemetryKey],
               Date().timeIntervalSince(last) < cooldown {
                continue // skip during cooldown
            }

            // Optional: lighten wording at night
            if context.period == .lateNight && sug.telemetryKey == "quick_add" {
                sug = AISuggestion(
                    title: sug.title,
                    detail: "Queue it for tomorrow morning so you can sleep well.",
                    reason: sug.reason,
                    ctas: sug.ctas,
                    telemetryKey: sug.telemetryKey,
                    score: sug.score
                )
            }

            out.append(sug)
        }

        // Sort by score (desc) and clip
        out.sort { $0.score > $1.score }
        return Array(out.prefix(perSessionLimit))
    }
}
