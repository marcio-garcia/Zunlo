//
//  MockNLService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/4/25.
//

import Foundation
@testable import Zunlo

public final class MockNLService: NLProcessing {
    public init() {}

    public func process(text: String) async throws -> [ToolResult] {
        return [ToolResult(
            intent: .showAgenda,
            message: "This is your agenda",
            richText: AttributedString("This is your agenda"))
        ]
    }

    public func dispatch(_ env: AIToolEnvelope) async throws -> ToolDispatchResult {
        if env.name == "echo" {
            return ToolDispatchResult(note: "echo: \(env.argsJSON)", ui: nil)
        }
        return ToolDispatchResult(note: "ran_\(env.name)", ui: nil)
    }
}
