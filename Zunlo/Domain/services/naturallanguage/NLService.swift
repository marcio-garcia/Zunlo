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
    private let parser: DateParser
    private let tool: Tools
    private let engine: IntentEngine
    private let calendar: Calendar
    
    public init(parser: DateParser, tool: Tools, engine: IntentEngine, calendar: Calendar) {
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
        
        var results: [ToolResult] = []
        for clause in splittedClauses {
            for pack in packs {
                let parsed = parser.parse(clause.text, now: Date(), pack: pack)
                log("parsed command: \(parsed)")
                let result = try await execute(parsed, now: Date(), calendar: cal)
                log("command result: \(result)")
                results.append(result)
            }
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
