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
    func process(text: String) async throws -> [ParseResult]
}

public struct ParseResult {
    public let title: String
    public let intent: Intent
    public let context: TemporalContext
}

public final class NLService: NLProcessing {
    private let parser: InputParser
    private let engine: IntentDetector
    private let calendar: Calendar
    
    public init(parser: InputParser, engine: IntentDetector, calendar: Calendar) {
        self.parser = parser
        self.engine = engine
        self.calendar = calendar
    }
    
    public func process(text: String) async throws -> [ParseResult] {
        
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
        
        var results: [ParseResult] = []
        for clause in splittedClauses {
            for pack in packs {
                let (title, intent, tokens) = parser.parse(clause.text, now: referenceDate, pack: pack)
                log("parsed command: \(tokens)")
                
                let interpreter = TemporalTokenInterpreter(calendar: calendar, timeZone: calendar.timeZone, referenceDate: referenceDate)
                let context = interpreter.interpret(tokens)
                let parseResult = ParseResult(title: title, intent: intent, context: context)
                results.append(parseResult)
            }
        }
        return results
    }
}
