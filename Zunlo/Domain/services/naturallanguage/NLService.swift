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
    func process(text: String) async throws -> [ToolResult]
}

public final class NLService: NLProcessing {
    private let parser: CommandParser
    private let tool: Tools
    private let engine: IntentEngine
    
    public init(parser: CommandParser, tool: Tools, engine: IntentEngine) {
        self.parser = parser
        self.tool = tool
        self.engine = engine
    }
    
    public func process(text: String) async throws -> [ToolResult] {
        var cal = Calendar.appDefault
        cal.timeZone = .current
        log("raw text: \(text), calendar: \(cal)")
        let language = engine.detectLanguage(text)
        log("language: \(language)")
        let splittedClauses = InputSplitter().split(text, language: language)
        log("splitted clauses: \(splittedClauses)")
        
        var results: [ToolResult] = []
        for clause in splittedClauses {
            let parsed = parser.parse(clause.text, now: Date(), calendar: cal)
            log("parsed command: \(parsed)")
            let result = try await execute(parsed, now: Date(), calendar: cal)
            log("command result: \(result)")
            results.append(result)
        }
        return results
    }
    
    private func execute(_ cmd: ParsedCommand, now: Date = Date(), calendar: Calendar = .current) async throws -> ToolResult {
        switch cmd.intent {
        case .createTask: return await tool.createTask(cmd)
        case .createEvent: return await tool.createEvent(cmd)
        case .updateEvent: return await tool.updateEvent(cmd)
        case .updateTask: return await tool.createTask(cmd)
        case .rescheduleTask: return await tool.rescheduleTask(cmd)
        case .rescheduleEvent: return await tool.rescheduleEvent(cmd)
        case .planWeek: return await tool.planWeek(cmd)
        case .planDay: return await tool.planDay(cmd)
        case .showAgenda: return await tool.showAgenda(cmd)
        case .moreInfo: return await tool.moreInfo(cmd)
        case .unknown: return await tool.unknown(cmd)
        }
    }
}
