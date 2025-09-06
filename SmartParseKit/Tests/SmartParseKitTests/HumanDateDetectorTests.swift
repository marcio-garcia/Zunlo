//
//  HumanDateDetectorTests.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/6/25.
//

import XCTest
@testable import SmartParseKit // ← replace with your module name

final class HumanDateDetectorTests: XCTestCase {

    // Helper: a Sao Paulo calendar + locale
    private func makeCal() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "pt_BR")
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        let cal = makeCal()
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return cal.date(from: comps)!
    }

    // Base: quarta-feira, 3 set 2025
    private var base: Date { date(2025, 9, 3) } // Wednesday

    func testEsteDomingo_immediateUpcoming_includingToday() {
        let cal = makeCal()
        let det = HumanDateDetector(
            calendar: cal,
            policy: .init(this: .upcomingIncludingToday, next: .immediateUpcoming),
            lexicon: .default(calendar: cal, locale: cal.locale!)
        )

        let text = "Vamos nos ver este domingo às 15:00."
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)

        // The upcoming Sunday from Sep 3, 2025 is Sep 7, 2025 at 15:00
        let expected = date(2025, 9, 7, 15, 0)
        XCTAssertEqual(m[0].date, expected)
        XCTAssertTrue(m[0].overridden)
    }

    func testProximoDomingo_defaultsToImmediateUpcoming() {
        let cal = makeCal()
        let det = HumanDateDetector(
            calendar: cal,
            policy: .init(this: .upcomingIncludingToday, next: .immediateUpcoming),
            lexicon: .default(calendar: cal, locale: cal.locale!)
        )

        let text = "A oficina é no próximo domingo às 10:00."
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)
        let expected = date(2025, 9, 7, 10, 0)
        XCTAssertEqual(m[0].date, expected)
        XCTAssertTrue(m[0].overridden)
    }

    func testDomingoQueVem_treatedAsNext() {
        let cal = makeCal()
        let det = HumanDateDetector(
            calendar: cal,
            policy: .init(this: .upcomingIncludingToday, next: .immediateUpcoming),
            lexicon: .default(calendar: cal, locale: cal.locale!)
        )

        let text = "Vamos marcar para domingo que vem às 09:30."
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)
        let expected = date(2025, 9, 7, 9, 30)
        XCTAssertEqual(m[0].date, expected)
        XCTAssertTrue(m[0].overridden)
    }

    func testSkipOneWeekPolicy() {
        let cal = makeCal()
        let det = HumanDateDetector(
            calendar: cal,
            policy: .init(this: .upcomingIncludingToday, next: .skipOneWeek),
            lexicon: .default(calendar: cal, locale: cal.locale!)
        )

        let text = "Reunião no próximo domingo às 10:00."
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)
        // Skip one full week → Sep 14, 2025
        let expected = date(2025, 9, 14, 10, 0)
        XCTAssertEqual(m[0].date, expected)
        XCTAssertTrue(m[0].overridden)
    }

    func testEsteDomingo_whenBaseIsSunday_includingTodayVsExcluding() {
        let cal = makeCal()
        let baseSunday = date(2025, 9, 7) // Sunday

        // Including today → same day
        let det1 = HumanDateDetector(
            calendar: cal,
            policy: .init(this: .upcomingIncludingToday, next: .immediateUpcoming),
            lexicon: .default(calendar: cal, locale: cal.locale!)
        )
        var m = det1.matches(in: "almoço este domingo às 12:00", base: baseSunday)
        XCTAssertEqual(m[0].date, date(2025, 9, 7, 12, 0))

        // Excluding today → next week
        let det2 = HumanDateDetector(
            calendar: cal,
            policy: .init(this: .upcomingExcludingToday, next: .immediateUpcoming),
            lexicon: .default(calendar: cal, locale: cal.locale!)
        )
        m = det2.matches(in: "almoço este domingo às 12:00", base: baseSunday)
        XCTAssertEqual(m[0].date, date(2025, 9, 14, 12, 0))
    }

    func testExplicitDatesRemainUntouched() {
        let cal = makeCal()
        let det = HumanDateDetector(
            calendar: cal,
            policy: .init(this: .upcomingIncludingToday, next: .immediateUpcoming),
            lexicon: .default(calendar: cal, locale: cal.locale!)
        )

        let text = "Evento 28/09/2025 às 18:45."
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)
        // Foundation parses 28/09/2025; we shouldn't override it.
        XCTAssertFalse(m[0].overridden)
    }

    func testNormalizedResolutions() {
        let cal = makeCal()
        let det = HumanDateDetector(
            calendar: cal,
            policy: .init(this: .upcomingIncludingToday, next: .immediateUpcoming),
            lexicon: .default(calendar: cal, locale: cal.locale!)
        )

        let text = "almoço este domingo às 12:00; oficina no próximo domingo às 10:00; encontro domingo que vem 19h"
        let rows = det.normalizedResolutions(in: text, base: base)
        XCTAssertEqual(rows.count, 3)

        // sanity checks
        XCTAssertTrue(rows.allSatisfy { $0.resolvedDate >= base })
        XCTAssertTrue(rows.contains { $0.modifier == .this })
        XCTAssertTrue(rows.filter { $0.modifier == .next }.count >= 2)
        // confirmation flag should trigger if we ever moved 7 days
        XCTAssertTrue(rows.allSatisfy { $0.needsConfirmation == (abs($0.deltaDays) >= 6) })
    }
}
