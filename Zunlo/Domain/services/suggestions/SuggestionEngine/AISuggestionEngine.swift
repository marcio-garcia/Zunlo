//
//  AISuggestionEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

private struct SugKey: Hashable {
    let telemetryKey: String
    let title: String
}

public struct AISuggestionEngine {
    private let suggesters: [AISuggester]
    public init(suggesters: [AISuggester]) { self.suggesters = suggesters }

    public func run(context: AIContext, limit: Int = 6) -> [AISuggestion] {
        // Collect
        var all: [AISuggestion] = []
        all.reserveCapacity(suggesters.count)
        for s in suggesters {
            if let sug = s.suggest(context: context) { all.append(sug) }
        }

        // Dedupe by (telemetryKey, title), keeping the highest score
        var bestByKey: [SugKey: AISuggestion] = [:]
        for s in all {
            let key = SugKey(telemetryKey: s.telemetryKey, title: s.title)
            if let existing = bestByKey[key] {
                if s.score > existing.score { bestByKey[key] = s }
            } else {
                bestByKey[key] = s
            }
        }

        // Rank and cap
        let ranked = bestByKey.values.sorted { $0.score > $1.score }
        return Array(ranked.prefix(limit))
    }
}
