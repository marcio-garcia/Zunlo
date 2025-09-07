//
//  InputSplitterTests.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/6/25.
//

import XCTest
import NaturalLanguage
@testable import SmartParseKit

final class InputSplitterTests: XCTestCase {

    private let splitter = InputSplitter()

    // MARK: - English

    func test_EN_TwoIntentsSeparatedByCommaThen() {
        let s = "Schedule lunch this Tuesday, then move my Thursday call to next Friday."
        let parts = splitter.split(s, language: .english)
        XCTAssertEqual(parts.map(\.text), [
            "Schedule lunch this Tuesday",
            "move my Thursday call to next Friday."
        ])
    }

    func test_EN_AndThenAlso() {
        let s = "Plan my week and then add a reminder for Sunday night; also show my agenda for tomorrow."
        let parts = splitter.split(s, language: .english)
        XCTAssertEqual(parts.map(\.text), [
            "Plan my week",
            "add a reminder for Sunday night",
            "show my agenda for tomorrow."
        ])
    }

    func test_EN_NoSplitInsideQuotes() {
        let s = "Create note \"call Tom and then email Sara\" and then schedule it for Friday."
        let parts = splitter.split(s, language: .english)
        XCTAssertEqual(parts.map(\.text), [
            "Create note \"call Tom and then email Sara\"",
            "schedule it for Friday."
        ])
    }

    func test_EN_NoSplitInsideParentheses() {
        let s = "Schedule the task (and then wait) and then set a reminder."
        let parts = splitter.split(s, language: .english)
        XCTAssertEqual(parts.map(\.text), [
            "Schedule the task (and then wait)",
            "set a reminder."
        ])
    }

    func test_EN_PoliteTailMerged() {
        let s = "Show my agenda for today. please"
        let parts = splitter.split(s, language: .english)
        XCTAssertEqual(parts.map(\.text), [
            "Show my agenda for today. please" // merged
        ])
    }

    // MARK: - Portuguese (pt-BR)

    func test_PT_TwoIntents_eDepois() {
        let s = "Agendar almoço nesta terça e depois mover minha ligação de quinta para o próximo domingo."
        let parts = splitter.split(s, language: NLLanguage(rawValue: "pt"))
        XCTAssertEqual(parts.map(\.text), [
            "Agendar almoço nesta terça",
            "mover minha ligação de quinta para o próximo domingo."
        ])
    }

    func test_PT_TresIntencoes() {
        let s = "Planejar minha semana, depois adicionar um lembrete para domingo, também mostrar a agenda de amanhã."
        let parts = splitter.split(s, language: NLLanguage(rawValue: "pt"))
        XCTAssertEqual(parts.map(\.text), [
            "Planejar minha semana",
            "adicionar um lembrete para domingo",
            "mostrar a agenda de amanhã."
        ])
    }

    func test_PT_NaoDivideDentroDeAspas() {
        let s = "Criar nota \"ligar para João e depois enviar email\" e depois agendar para sexta."
        let parts = splitter.split(s, language: NLLanguage(rawValue: "pt"))
        XCTAssertEqual(parts.map(\.text), [
            "Criar nota \"ligar para João e depois enviar email\"",
            "agendar para sexta."
        ])
    }

    func test_PT_PorFavorFundido() {
        let s = "Mostrar minha agenda de hoje. por favor"
        let parts = splitter.split(s, language: NLLanguage(rawValue: "pt"))
        XCTAssertEqual(parts.map(\.text), [
            "Mostrar minha agenda de hoje. por favor" // merged
        ])
    }

    // MARK: - Mixed punctuation / edge cases

    func test_SemicolonAndEmDash() {
        let s = "Schedule lunch Tuesday; then reschedule standup — also move 1:1 to Friday."
        let parts = splitter.split(s, language: .english)
        XCTAssertEqual(parts.map(\.text), [
            "Schedule lunch Tuesday",
            "reschedule standup",
            "move 1:1 to Friday."
        ])
    }

    func test_SingleSentenceNoConnectors() {
        let s = "Schedule lunch Tuesday"
        let parts = splitter.split(s, language: .english)
        XCTAssertEqual(parts.map(\.text), ["Schedule lunch Tuesday"])
    }

    func test_EmptyAndWhitespace() {
        XCTAssertTrue(splitter.split("", language: .english).isEmpty)
        XCTAssertTrue(splitter.split("   ", language: .english).isEmpty)
    }
}
