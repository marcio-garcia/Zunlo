//
//  QuickAddSuggester.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

public struct QuickAddSuggester: AISuggester {
    public init() {}
    public func suggest(context: AIContext) -> AISuggestion? {
        let suggestedTime: String
        switch context.period {
        case .evening: suggestedTime = "6pm"
        case .morning, .afternoon: suggestedTime = "today"
        default: suggestedTime = "tomorrow morning"
        }
        let title = "Add a quick task"
        let detail = "Try “Buy gift for Ana \(suggestedTime) • High”"
        let reason = "Fast capture reduces mental load."
        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: "Add with AI") {
                    // Open your Add sheet with NLP prefill
                }
            ],
            telemetryKey: "quick_add",
            score: 60
        )
    }
}
