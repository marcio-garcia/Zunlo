//
//  MockNLService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/4/25.
//

import Foundation
import SmartParseKit
@testable import Zunlo

public final class MockNLService: NLProcessing {
    public init() {}

    public func process(text: String, referenceDate: Date) async throws -> [ParseResult] {
        let calendar = Calendar(identifier: .gregorian)
        let duration: TimeInterval = 60 * 60 * 24
        let today = calendar.startOfDay(for: referenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(duration)
        let range = DateInterval(start: today, end: tomorrow)
        return [ParseResult(title: "This is your agenda",
                            intent: .view,
                            context: TemporalContext(finalDate: today,
                                                     finalDateDuration: duration,
                                                     dateRange: range,
                                                     confidence: 1.0,
                                                     resolvedTokens: [],
                                                     conflicts: [],
                                                     isRangeQuery: true))
        ]
    }

    public func dispatch(_ env: AIToolEnvelope) async throws -> ToolDispatchResult {
        if env.name == "echo" {
            return ToolDispatchResult(note: "echo: \(env.argsJSON)", ui: nil)
        }
        return ToolDispatchResult(note: "ran_\(env.name)", ui: nil)
    }
}
