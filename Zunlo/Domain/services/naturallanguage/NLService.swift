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
    func process(text: String, referenceDate: Date) async throws -> [ParseResult]
}

extension NLProcessing {
    func process(text: String, referenceDate: Date) async throws -> [ParseResult] {
        try await process(text: text, referenceDate: referenceDate)
    }
}

public final class NLService: NLProcessing {
    private let parser: InputParser
    private let intentDetector: IntentDetector
    private let calendar: Calendar
    
    public init(parser: InputParser, intentDetector: IntentDetector, calendar: Calendar) {
        self.parser = parser
        self.intentDetector = intentDetector
        self.calendar = calendar
    }
    
    public func process(text: String, referenceDate: Date) async throws -> [ParseResult] {
        
        // Language
        let language = intentDetector.detectLanguage(text)
        
        // Build a calendar localized to the detected language
        var cal = calendar
        cal.locale = Locale(identifier: language.rawValue)

        // Build language packs based on calendar
        var packs: [DateLanguagePack]
        if language.rawValue == "pt" {
            packs = [PortugueseBRPack(calendar: cal)]
        } else if language.rawValue == "es" {
            packs = [SpanishPack(calendar: cal)]
        } else {
            packs = [EnglishPack(calendar: cal)]
        }
        
        log("raw text: \(text), calendar: \(cal)")
        
        // Preprocess input to detect multiple clauses
        let splittedClauses = InputSplitter().split(text, language: language)
        log("splitted clauses: \(splittedClauses)")
        
        var results: [ParseResult] = []
        for clause in splittedClauses {
            for pack in packs {
                let (intent, temporalTokens, metadataResult) = parser.parse(clause.text, now: referenceDate, pack: pack, intentDetector: AppleIntentDetector.bundled())
                log("parsed intent: \(intent)")
                log("parsed temporal tokens: \(temporalTokens.map({ $0.kind }))")
                log("parsed metadata tokens: \(metadataResult.tokens.map { "\($0.kind)" })")

                let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: referenceDate)
                let context = interpreter.interpret(temporalTokens)

                log("command context: \(context)")
                log("metadata: \(metadataResult)")
                
                let parseResult = ParseResult(
                    id: UUID(),
                    originalText: text,
                    title: metadataResult.title,
                    intent: intent,
                    context: context,
                    metadataTokens: metadataResult.tokens
                )
                log("parse result: \(parseResult)")
                results.append(parseResult)
            }
        }
        return results
    }
}
