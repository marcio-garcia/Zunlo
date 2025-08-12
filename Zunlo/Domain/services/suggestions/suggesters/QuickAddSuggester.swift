//
//  QuickAddSuggester.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

//QuickAddSuggester uses period to tailor the copy.
public struct QuickAddSuggester: AISuggester {
    public init() {}
    public func suggest(context: AIContext) -> AISuggestion? {
        let targetTime: String
        switch context.period {
        case .evening:     targetTime = "6 pm"
        case .morning:     targetTime = "10 am"
        case .afternoon:   targetTime = "3 pm"
        case .earlyMorning:targetTime = "today"
        case .lateNight:   targetTime = "tomorrow morning"
        }

        let title  = "Add a quick task"
        let detail = "Try “Buy gift for Ana • \(targetTime) • High”."
        let reason = "Fast capture reduces mental load."

        return AISuggestion(
            title: title,
            detail: detail,
            reason: reason,
            ctas: [
                AISuggestionCTA(title: "Add with AI") {
                    // nav.presentQuickAdd(prefill: "Buy gift for Ana at \(targetTime) • High")
                }
            ],
            telemetryKey: "quick_add",
            score: 70
        )
    }
}
