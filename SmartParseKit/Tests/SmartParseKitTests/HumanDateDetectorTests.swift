//
//  HumanDateDetectorTests.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/6/25.
//

import XCTest
@testable import SmartParseKit

final class HumanDateDetectorTests: XCTestCase {

    // MARK: - Helpers

    // São Paulo calendar + locale
    private func makeCal() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "pt_BR")
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return cal
    }

    // Default detector with Portuguese + English packs
    private func makeDetector(
        cal: Calendar? = nil,
        policy: RelativeWeekdayPolicy = .init(),
        extraPacks: [DateLanguagePack] = []
    ) -> HumanDateDetector {
        let c = cal ?? makeCal()
        var packs: [DateLanguagePack] = [
            PortugueseBRPack(calendar: c),
            EnglishPack(calendar: c),
        ]
        packs.append(contentsOf: extraPacks)
        return HumanDateDetector(calendar: c, policy: policy, packs: packs, dateDetector: FakeDateDetector())
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        let cal = makeCal()
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return cal.date(from: comps)!
    }

    // Base: quarta-feira, 3 set 2025 (Wednesday)
    private var base: Date { date(2025, 9, 3) }

    // MARK: - Weekday phrases & policies

    func testEsteDomingo_immediateUpcoming_includingToday() {
        let cal = makeCal()
        let det = makeDetector(
            cal: cal,
            policy: RelativeWeekdayPolicy(
                this: .upcomingIncludingToday,
                next: .immediateUpcoming,
                defaultSingleDuration: 0)
        )

        let text = "Vamos nos ver este domingo às 15:00."
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)

        // Upcoming Sunday from Sep 3, 2025 is Sep 7, 2025 at 15:00
        let expected = date(2025, 9, 7, 15, 0)
        XCTAssertEqual(m[0].date, expected)
        XCTAssertTrue(m[0].overridden)
    }

    func testProximoDomingo_defaultsToImmediateUpcoming() {
        let cal = makeCal()
        let det = makeDetector(
            cal: cal,
            policy: .init(this: .upcomingIncludingToday, next: .immediateUpcoming)
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
        let det = makeDetector(
            cal: cal,
            policy: .init(this: .upcomingIncludingToday, next: .immediateUpcoming)
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
        let det = makeDetector(
            cal: cal,
            policy: .init(this: .upcomingIncludingToday, next: .skipOneWeek)
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
        let det1 = makeDetector(
            cal: cal,
            policy: .init(this: .upcomingIncludingToday, next: .immediateUpcoming)
        )
        var m = det1.matches(in: "almoço este domingo às 12:00", base: baseSunday)
        XCTAssertEqual(m[0].date, date(2025, 9, 7, 12, 0))

        // Excluding today → next week
        let det2 = makeDetector(
            cal: cal,
            policy: .init(this: .upcomingExcludingToday, next: .immediateUpcoming)
        )
        m = det2.matches(in: "almoço este domingo às 12:00", base: baseSunday)
        XCTAssertEqual(m[0].date, date(2025, 9, 14, 12, 0))
    }

    func testExplicitDatesRemainUntouched() {
        let cal = makeCal()
        let det = makeDetector(
            cal: cal,
            policy: .init(this: .upcomingIncludingToday, next: .immediateUpcoming)
        )

        let text = "Evento 28/09/2025 às 18:45."
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)
        // Foundation parses 28/09/2025; we shouldn't override it.
        XCTAssertFalse(m[0].overridden)
    }

    func testNormalizedResolutions() {
        let cal = makeCal()
        let det = makeDetector(
            cal: cal,
            policy: .init(this: .upcomingIncludingToday, next: .immediateUpcoming)
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

    // MARK: - Inline weekday + time(/range) and from–to patterns

    func testInline_EN_Weekday_9to10() {
        let cal = makeCal()
        let det = makeDetector(cal: cal, policy: .init())

        let text = "Create event meeting wed 9-10"
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)

        // Base is Wed Sep 3, 2025 → upcoming Wed is Sep 10, 2025 (excluding today)
        XCTAssertEqual(m[0].date, date(2025, 9, 10, 9, 0))
        XCTAssertEqual(m[0].duration, 60 * 60) // 1h defaultSingleDuration for single time becomes 1h here because it's a range
        XCTAssertTrue(m[0].overridden)
    }

    func testInline_PT_Weekday_10hTo12h() {
        let cal = makeCal()
        let det = makeDetector(
            cal: cal,
            policy: RelativeWeekdayPolicy(this: .upcomingExcludingToday,
                                          next: .immediateUpcoming,
                                          defaultSingleDuration: 0))

        let text = "reunião qua 10h-12h"
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)

        // Base Wed Sep 3 → next Wed Sep 10
        XCTAssertEqual(m[0].date, date(2025, 9, 10, 10, 0))
        XCTAssertEqual(m[0].duration, 2 * 60 * 60) // 2h
        XCTAssertTrue(m[0].overridden)
    }

    func testInline_SingleTime_DefaultDuration() {
        let cal = makeCal()
        let det = makeDetector(
            cal: cal,
            policy: .init(defaultSingleDuration: 90 * 60) // customize to verify
        )

        let text = "standup fri 9"
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 2)

        // Base Wed Sep 3 → next Fri Sep 5
        XCTAssertEqual(m[0].date, date(2025, 9, 9, 12, 0))
        XCTAssertEqual(m[0].duration, 0)
        XCTAssertFalse(m[0].overridden)
        XCTAssertEqual(m[1].date, date(2025, 9, 5, 9, 0))
        XCTAssertEqual(m[1].duration, 90 * 60) // 90 minutes as per policy override
        XCTAssertTrue(m[1].overridden)
        XCTAssertTrue(m[1].ambiguous)
        XCTAssertNotNil(m[1].ambiguityReason)
    }

    func testInline_EN_AMPMAlignment() {
        let cal = makeCal()
        let det = makeDetector(cal: cal, policy: .init())

        let text = "fri 9am-10"
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)

        XCTAssertEqual(m[0].date, date(2025, 9, 5, 9, 0))
        XCTAssertEqual(m[0].duration, 60 * 60)
        XCTAssertTrue(m[0].overridden)
    }

    func testInline_PT_Shorthand_11to1() {
        let cal = makeCal()
        let det = makeDetector(cal: cal, policy: .init())

        let text = "sex 11-1"
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)

        // Next Friday Sep 5: 11:00 → 13:00 (add +12h on end when needed)
        XCTAssertEqual(m[0].date, date(2025, 9, 5, 11, 0))
        XCTAssertEqual(m[0].duration, 2 * 60 * 60)
        XCTAssertTrue(m[0].overridden)
    }

    func testInline_PT_Weekday_WithPreposition_As() {
        let cal = makeCal()
        let det = makeDetector(cal: cal, policy: .init())

        let text = "qua às 10h-11h"
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)

        // Next Wednesday Sep 10
        XCTAssertEqual(m[0].date, date(2025, 9, 10, 10, 0))
        XCTAssertEqual(m[0].duration, 60 * 60)
        XCTAssertTrue(m[0].overridden)
    }

    func testPT_FromTo_WithWeekday() {
        let cal = makeCal()
        let det = makeDetector(cal: cal, policy: .init())

        let text = "quarta das 9 às 10"
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)

        // Base Wed Sep 3 → upcoming Wed Sep 10
        XCTAssertEqual(m[0].date, date(2025, 9, 10, 9, 0))
        XCTAssertEqual(m[0].duration, 60 * 60)
        XCTAssertTrue(m[0].overridden)
    }

    func testPT_FromTo_NoWeekday_Today() {
        let cal = makeCal()
        let det = makeDetector(cal: cal, policy: .init())

        let text = "das 14 às 16"
        let m = det.matches(in: text, base: base) // base at 00:00
        XCTAssertEqual(m.count, 1)

        // Same day (Wed Sep 3), from 14:00 to 16:00
        XCTAssertEqual(m[0].date, date(2025, 9, 3, 14, 0))
        XCTAssertEqual(m[0].duration, 2 * 60 * 60)
        XCTAssertTrue(m[0].overridden)
    }

    func testPT_FromTo_Suffixes() {
        let cal = makeCal()
        let det = makeDetector(cal: cal, policy: .init())

        let text = "de 10hs a 12hrs"
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)

        XCTAssertEqual(m[0].date, date(2025, 9, 3, 10, 0))
        XCTAssertEqual(m[0].duration, 2 * 60 * 60)
        XCTAssertTrue(m[0].overridden)
    }

    func testEN_FromTo_WithWeekday() {
        let cal = makeCal()
        let det = makeDetector(cal: cal, policy: .init())

        let text = "wed from 9 to 10"
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)

        XCTAssertEqual(m[0].date, date(2025, 9, 10, 9, 0))
        XCTAssertEqual(m[0].duration, 60 * 60)
        XCTAssertTrue(m[0].overridden)
    }

    func testEN_FromTo_NoWeekday_Today() {
        let cal = makeCal()
        let det = makeDetector(cal: cal, policy: .init())

        let text = "from 9:30 to 10:15"
        let m = det.matches(in: text, base: base)
        XCTAssertEqual(m.count, 1)

        XCTAssertEqual(m[0].date, date(2025, 9, 3, 9, 30))
        XCTAssertEqual(m[0].duration, 45 * 60)
        XCTAssertTrue(m[0].overridden)
    }

    func testFromTo_NoWeekday_RollsToTomorrowIfPast() {
        let cal = makeCal()
        let det = makeDetector(cal: cal, policy: .init())

        // Base at 21:00 — "from 20 to 21" is already past / ends at base time → roll to tomorrow
        let baseLate = date(2025, 9, 3, 21, 0)
        let text = "from 20 to 21"
        let m = det.matches(in: text, base: baseLate)
        XCTAssertEqual(m.count, 1)

        XCTAssertEqual(m[0].date, date(2025, 9, 4, 20, 0)) // rolled to next day
        XCTAssertEqual(m[0].duration, 60 * 60)
        XCTAssertTrue(m[0].overridden)
    }
}
