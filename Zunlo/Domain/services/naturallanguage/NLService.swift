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
        let packs: [DateLanguagePack] = [
            PortugueseBRPack(calendar: cal),
            SpanishPack(calendar: cal),
            EnglishPack(calendar: cal)
        ]
        
        var languagePack: DateLanguagePack = EnglishPack(calendar: cal)
        
        if let pack = selectLanguagePack(text: text, packs: packs, calendar: cal) {
            languagePack = pack
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
    
    private func selectLanguagePack(text: String, packs: [DateLanguagePack], calendar: Calendar) -> DateLanguagePack? {
        var languagePack: DateLanguagePack?
        var hits: [Int] = Array(repeating: 0, count: packs.count)
        
        if languagePack == nil {
            for (index, _) in packs.enumerated() {
                let list = [
                    packs[index].taskKeywordsRegex(),
                    packs[index].eventKeywordsRegex(),
                    packs[index].metadataAdditionWithPrepositionRegex(),
                    packs[index].metadataAdditionDirectRegex(),
                    packs[index].eventKeywordsRegex(),
                    packs[index].timePivotRegex(),
                    packs[index].weekendRegex(),
                    packs[index].relativeDayRegex(),
                    packs[index].partOfDayRegex(),
                    packs[index].ordinalDayRegex(),
                    packs[index].timeOnlyRegex(),
                    packs[index].betweenTimeRegex(),
                    packs[index].inFromNowRegex(),
                    packs[index].articleFromNowRegex(),
                    packs[index].byOffsetRegex(),
                    packs[index].titleTokenRegex(),
                    packs[index].tagPatternRegex(),
                    packs[index].reminderPatternRegex(),
                    packs[index].priorityPatternRegex(),
                    packs[index].locationPatternRegex(),
                    packs[index].notesPatternRegex()
                ]
                let regexList = packs[index].commandPrefixRegex() + list
                for regex in regexList {
                    if let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
                       match.range.length > 0 {
                        
                        hits[index] += 1
                    }
                }
            }
        }
        
        guard let (max, isDraw) = greatestWithDraw(in: hits) else { return nil }
        
        if isDraw {
            let lang = intentDetector.detectLanguage(text)
            switch lang.rawValue {
            case "pt": return PortugueseBRPack(calendar: calendar)
            case "es": return SpanishPack(calendar: calendar)
            default: return EnglishPack(calendar: calendar)
            }
        }
        
        guard let index = hits.firstIndex(of: max) else { return nil }
        
        return packs[index]
    }
    
    /// - Returns: nil if empty; otherwise the max and a `isDraw` flag.
    private func greatestWithDraw(in numbers: [Int]) -> (max: Int, isDraw: Bool)? {
        guard var best = numbers.first else { return nil }
        var count = 1

        for n in numbers.dropFirst() {
            if n > best {
                best = n
                count = 1
            } else if n == best {
                count += 1
            }
        }
        return (best, count > 1)
    }
}
