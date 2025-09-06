//
//  NLService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/1/25.
//

import Foundation
import SmartParseKit
import LoggingKit

public protocol NLProcessing {
    func process(text: String) async throws -> CommandResult
}

public final class NLService: NLProcessing {
    private let parser: CommandParser
    private let executor: AnyCommandExecutor
    private let engine: IntentEngine
    
    public init(parser: CommandParser, executor: AnyCommandExecutor, engine: IntentEngine) {
        self.parser = parser
        self.executor = executor
        self.engine = engine
    }
    
    public func process(text: String) async throws -> CommandResult {
        var cal = Calendar.appDefault
        cal.timeZone = .current
        log("raw text: \(text), calendar: \(cal)")
        let parsed = parser.parse(text, now: Date(), calendar: cal)
        log("parsed command: \(parsed)")
        let result = try await executor.execute(parsed, now: Date(), calendar: cal)
        log("command result: \(result)")
        return result
    }
}
