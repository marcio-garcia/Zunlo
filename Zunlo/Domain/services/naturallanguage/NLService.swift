//
//  NLService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/1/25.
//

import Foundation
import SmartParseKit

public final class NLService {
    private let parser: CommandParser
    private let executor: AnyCommandExecutor
    private let engine: IntentEngine
    
    public init(parser: CommandParser, executor: AnyCommandExecutor, engine: IntentEngine) {
        self.parser = parser
        self.executor = executor
        self.engine = engine
    }
    
    public func process(text: String) async -> CommandResult? {
        var cal = Calendar.appDefault
        cal.timeZone = .current
        
        do {
            let parsed = parser.parse(text, now: Date(), calendar: cal)
//            let result = try await executor.execute(parsed, now: Date(), calendar: cal)
//            return result
            print(parsed)
            return nil
        } catch {
            print(error)
            return nil
        }
    }
}
