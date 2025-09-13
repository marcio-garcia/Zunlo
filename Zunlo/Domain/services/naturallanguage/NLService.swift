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

public struct ParseResult {
    public let title: String
    public let intent: Intent
    public let context: TemporalContext
}

public final class NLService: NLProcessing {
    private let parser: InputParser
    private let tool: Tools
    private let engine: IntentEngine
    private let calendar: Calendar
    
    public init(parser: InputParser, tool: Tools, engine: IntentEngine, calendar: Calendar) {
        self.parser = parser
        self.tool = tool
        self.engine = engine
        self.calendar = calendar
    }
    
    public func process(text: String) async throws -> [ToolResult] {
        
        // Language
        let language = engine.detectLanguage(text)
        
        // Build a calendar localized to the detected language
        var cal = calendar
        cal.locale = Locale(identifier: language.rawValue)

        // Build language packs based on calendar
        let packs: [DateLanguagePack] = language.rawValue == "en" ? [EnglishPack(calendar: cal)] : [PortugueseBRPack(calendar: cal)]
        log("raw text: \(text), calendar: \(cal)")
        
        // Preprocess input to detect multiple clauses
        let splittedClauses = InputSplitter().split(text, language: language)
        log("splitted clauses: \(splittedClauses)")
        
        let referenceDate = Date()
        
        var results: [ToolResult] = []
        for clause in splittedClauses {
            for pack in packs {
                let (title, intent, tokens) = parser.parse(clause.text, now: referenceDate, pack: pack)
                log("parsed command: \(tokens)")
                
                let interpreter = TemporalTokenInterpreter(calendar: calendar, timeZone: calendar.timeZone, referenceDate: referenceDate)
                let context = interpreter.interpret(tokens)
                let parseResult = ParseResult(title: title, intent: intent, context: context)
                
                let result = try await execute(parseResult, now: Date(), calendar: cal)
                log("command result: \(result)")
                results.append(result)
            }
        }
        return results
    }
    
    private func execute(_ cmd: ParseResult, now: Date = Date(), calendar: Calendar = .current) async throws -> ToolResult {
        switch cmd.intent {
        case .createTask: return await tool.createTask(cmd)
        case .createEvent: return await tool.createEvent(cmd)
        case .updateEvent: return await tool.updateEvent(cmd)
        case .updateTask: return await tool.createTask(cmd)
        case .rescheduleTask: return await tool.rescheduleTask(cmd)
        case .rescheduleEvent: return await tool.rescheduleEvent(cmd)
        case .cancelTask: return ToolResult(intent: .cancelTask)
        case .cancelEvent: return ToolResult(intent: .cancelEvent)
        case .plan: return await tool.planWeek(cmd)
        case .view: return await tool.planWeek(cmd)
//        case .planWeek: return await tool.planWeek(cmd)
//        case .planDay: return await tool.planDay(cmd)
//        case .showAgenda: return await tool.showAgenda(cmd)
//        case .moreInfo: return await tool.moreInfo(cmd)
        case .unknown: return await tool.unknown(cmd)
        }
    }
}
