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

    public func process(text: String) async throws -> [SmartParseKit.CommandResult] {
        return [SmartParseKit.CommandResult(
            outcome: .agenda,
            message: "This is your agenda",
            attributedString: AttributedString("This is your agenda")
        )]
    }

    public func dispatch(_ env: AIToolEnvelope) async throws -> ToolDispatchResult {
        if env.name == "echo" {
            return ToolDispatchResult(note: "echo: \(env.argsJSON)", ui: nil)
        }
        return ToolDispatchResult(note: "ran_\(env.name)", ui: nil)
    }
}
