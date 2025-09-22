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
        var packs: [DateLanguagePack] = [
            PortugueseBRPack(calendar: cal),
            SpanishPack(calendar: cal),
            EnglishPack(calendar: cal)
        ]
        
        var languagePack: DateLanguagePack = EnglishPack(calendar: cal)
            
        for (index, value) in packs.enumerated() {
            let regexList = packs[index].commandPrefixRegex()
            for regex in regexList {
                if let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
                   match.range.location == 0, match.range.length > 0,
                   let range = Range(match.range(at: 1), in: text) {
                    
                    languagePack = packs[index]
                    
                }
            }
        }
        
        log("raw text: \(text), calendar: \(cal)")
        
        // Preprocess input to detect multiple clauses
        let splittedClauses = InputSplitter().split(text, language: language)
        log("splitted clauses: \(splittedClauses)")
        
        var results: [ParseResult] = []
        for clause in splittedClauses {
            let (temporalTokens, metadataResult) = parser.parse(clause.text, now: referenceDate, pack: languagePack)
            
            log("parsed temporal tokens: \(temporalTokens.map({ $0.kind }))")
            log("parsed metadata tokens: \(metadataResult.tokens.map { "\($0.kind)" })")

            // Use new intent interpreter for classification
            let intentInterpreter = IntentInterpreter()
            let intentAmbiguity = intentInterpreter.classify(inputText: text, metadataTokens: metadataResult.tokens, temporalTokens: temporalTokens, languagePack: languagePack)
            log("parsed intent: \(intentAmbiguity.primaryIntent)")

            let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: referenceDate)
            let context = interpreter.interpret(temporalTokens)

            log("command context: \(context)")
            log("metadata: \(metadataResult)")
            
            let parseResult = ParseResult(
                id: UUID(),
                originalText: text,
                title: metadataResult.title,
                intent: intentAmbiguity.primaryIntent,
                context: context,
                metadataTokens: metadataResult.tokens,
                intentAmbiguity: intentAmbiguity
            )
            log("parse result: \(parseResult)")
            results.append(parseResult)
        }
        return results
    }
}
