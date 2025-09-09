//
//  TitleExtractorTests.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/9/25.
//

import XCTest
@testable import SmartParseKit

final class TitleExtractorTests: XCTestCase {

    // MARK: - Helpers

    // São Paulo calendar + locale for determinism
    private func makeCal() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "pt_BR")
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return cal
    }

    // Build a detector with EN + PT + ES packs.
    // We rely on our synthetic regex (not Apple’s detector), so pass the real wrapper if you want,
    // or inject your FakeDateDetector if you prefer full determinism.
    private func makeDetector(cal: Calendar? = nil) -> HumanDateDetector {
        let c = cal ?? makeCal()
        let packs: [DateLanguagePack] = [
            EnglishPack(calendar: c),
            PortugueseBRPack(calendar: c),
            SpanishPack(calendar: c)
        ]
        return HumanDateDetector(calendar: c,
                                 policy: .init(),
                                 packs: packs)
    }

    private var base: Date {
        // Fixed base: Wed, Sep 3, 2025
        var comps = DateComponents()
        comps.year = 2025; comps.month = 9; comps.day = 3; comps.hour = 0; comps.minute = 0
        return makeCal().date(from: comps)!
    }

    // Convenience
    private func extractor() -> TitleExtractor {
        TitleExtractor(detector: makeDetector())
    }

    // MARK: - English

    func testEN_RemovesInlineWeekdayRange() {
        let title = extractor().extractTitle(from: "Create event meeting wed 9-10", base: base)
        XCTAssertEqual(title, "meeting")
    }

    func testEN_RemovesAdditionalCommandWords() {
        let title = extractor().extractTitle(from: "book event meeting wed 9-10", base: base)
        XCTAssertEqual(title, "meeting")
    }
    
    func testEN_RemovesFromToRange() {
        let title = extractor().extractTitle(from: "Schedule onboarding from 14 to 16", base: base)
        XCTAssertEqual(title, "onboarding")
    }

    func testEN_RemovesPrepositionsAndKeepsCore() {
        let title = extractor().extractTitle(from: "Call John on fri at 9am", base: base)
        // connectors "on" + "at" should be stripped
        XCTAssertEqual(title, "Call John")
    }

    // MARK: - Portuguese (pt-BR)

    func testPT_RemovesFromToWithWeekday() {
        let title = extractor().extractTitle(from: "Adicionar lembrete pagar contas quarta das 9 às 10", base: base)
        XCTAssertEqual(title, "pagar contas")
    }

    func testPT_RemovesInlineRange() {
        let title = extractor().extractTitle(from: "Reunião sex 11-1", base: base)
        XCTAssertEqual(title, "Reunião")
    }

    func testPT_RemovesConnectors() {
        let title = extractor().extractTitle(from: "qua às 10h-11h apresentação do projeto", base: base)
        // “qua às 10h-11h” should be removed along with “às”
        XCTAssertEqual(title, "apresentação do projeto")
    }

    // MARK: - Spanish

    func testES_RemovesFromToWithWeekday() {
        let title = extractor().extractTitle(from: "Programar llamada con Ana el miércoles de 9 a 10", base: base)
        // “el” should be stripped (connector), as well as the time span
        XCTAssertEqual(title, "llamada con Ana")
    }

    // MARK: - Mixed / Edge

    func testNoDatesReturnsTrimmedOriginal() {
        let title = extractor().extractTitle(from: "Buy milk and eggs", base: base)
        XCTAssertEqual(title, "Buy milk and eggs")
    }
}
