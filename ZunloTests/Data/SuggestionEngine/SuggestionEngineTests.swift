//
//  SuggestionEngineTests.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

import XCTest
@testable import Zunlo

// MARK: - Tests (only the refactored engine)

final class SuggestionEngineTests: XCTestCase {

    // Replace with your engine type if named differently.
    private func makeEngine(with events: [EventOccurrence]) -> DefaultEventSuggestionEngine {
        DefaultEventSuggestionEngine(calendar: DT.cal, eventFetcher: FakeEventFetcher(events))
    }

    private var sampleDate: Date { DT.d("2025-08-12 12:00") } // any time that day (UTC)

    /// Sample day events (UTC), matching our earlier examples.
    private func sampleEvents() -> [EventOccurrence] {
        return [
            // F: Aug 11 23:30 – Aug 12 01:00 (spills in)
            .init(startDate: DT.d("2025-08-11 23:30"), endDate: DT.d("2025-08-12 01:00")),
            // A: 06:30 – 08:15
            .init(startDate: DT.d("2025-08-12 06:30"), endDate: DT.d("2025-08-12 08:15")),
            // B: 09:00 – 10:00
            .init(startDate: DT.d("2025-08-12 09:00"), endDate: DT.d("2025-08-12 10:00")),
            // C: 09:30 – 10:30 (overlaps B)
            .init(startDate: DT.d("2025-08-12 09:30"), endDate: DT.d("2025-08-12 10:30")),
            // D: 10:30 – 11:00 (adjacent to C)
            .init(startDate: DT.d("2025-08-12 10:30"), endDate: DT.d("2025-08-12 11:00")),
            // E: 22:00 – nil (treated as 22:00–24:00 in engine)
            .init(startDate: DT.d("2025-08-12 22:00"), endDate: nil),
            // G: 23:30 – Aug 13 00:30 (spills out)
            .init(startDate: DT.d("2025-08-12 23:30"), endDate: DT.d("2025-08-13 00:30")),
        ]
    }

    // Full-day availability helper (00:00–24:00) to test “pure algorithm” in UTC.
    private var fullDayUTC: SuggestionPolicy {
        // start == end => overnight window; engine should treat as full day
        SuggestionPolicy(
            absorbGapsBelow: 0,
            availabilityStartHour: 0, availabilityStartMinute: 0,
            availabilityEndHour: 0, availabilityEndMinute: 0,
            availabilityTimeZone: .gmt
        )
    }

    // MARK: - Free windows (full UTC day)

    func testFreeWindows_fullDay_min60() async throws {
        let engine = makeEngine(with: sampleEvents())
        let free = await engine.freeWindows(on: sampleDate, minimumMinutes: 60, policy: fullDayUTC)

        // Expect [01:00–06:30] and [11:00–22:00]
        XCTAssertEqual(free.count, 2)
        XCTAssertEqual(free[0].start, DT.d("2025-08-12 01:00"))
        XCTAssertEqual(free[0].end,   DT.d("2025-08-12 06:30"))
        XCTAssertEqual(free[1].start, DT.d("2025-08-12 11:00"))
        XCTAssertEqual(free[1].end,   DT.d("2025-08-12 22:00"))
    }

    // MARK: - Next event start (full UTC day)

    func testNextEventStart_fullDay_examples() async throws {
        let engine = makeEngine(with: sampleEvents())

        let s1 = await engine.nextEventStart(after: DT.d("2025-08-12 08:20"), on: sampleDate, policy: fullDayUTC)
        XCTAssertEqual(s1, DT.d("2025-08-12 09:00"))

        let s2 = await engine.nextEventStart(after: DT.d("2025-08-12 10:45"), on: sampleDate, policy: fullDayUTC)
        XCTAssertEqual(s2, DT.d("2025-08-12 22:00"))

        let s3 = await engine.nextEventStart(after: DT.d("2025-08-12 23:50"), on: sampleDate, policy: fullDayUTC)
        XCTAssertNil(s3)
    }

    // MARK: - Conflicts (pairwise overlaps on raw, day-clamped intervals)

    func testConflictingItemsCount_fullDay_isTwo() async throws {
        let engine = makeEngine(with: sampleEvents())
        let count = await engine.conflictingItemsCount(on: sampleDate, policy: fullDayUTC)
        XCTAssertEqual(count, 2, "B∩C and E∩G")
    }

    // MARK: - Absorb tiny gaps (swallow the 45-minute slit 08:15–09:00)

    func testAbsorbGaps_swallow45m_gap() async throws {
        let engine = makeEngine(with: sampleEvents())
        var policy = fullDayUTC
        policy.absorbGapsBelow = 60*60 // 60 minutes

        let free = await engine.freeWindows(on: sampleDate, minimumMinutes: 0, policy: policy)

        // Ensure there is NO free window exactly [08:15–09:00] after absorption.
        let hasGap = free.contains { $0.start == DT.d("2025-08-12 08:15") && $0.end == DT.d("2025-08-12 09:00") }
        XCTAssertFalse(hasGap, "45-minute slit should be absorbed when threshold is 60m")
    }

    // MARK: - Availability: São Paulo local 08:00–20:00 (UTC−3) clamps “night”

    func testAvailability_SaoPaulo_daytimeOnly() async throws {
        let engine = makeEngine(with: sampleEvents())
        let spTZ = TimeZone(identifier: "America/Sao_Paulo")!

        var policy = SuggestionPolicy(
            absorbGapsBelow: 0,
            availabilityStartHour: 8, availabilityStartMinute: 0,
            availabilityEndHour: 20, availabilityEndMinute: 0,
            availabilityTimeZone: spTZ
        )

        // Free windows should only appear inside local 08–20, which is 11:00–23:00 UTC.
        // Given our events, busy inside availability becomes [22:00–23:00], so free is [11:00–22:00].
        let free = await engine.freeWindows(on: sampleDate, minimumMinutes: 0, policy: policy)
        XCTAssertEqual(free.count, 1)
        XCTAssertEqual(free[0].start, DT.d("2025-08-12 11:00"))
        XCTAssertEqual(free[0].end,   DT.d("2025-08-12 22:00"))

        // Next event start respects availability window (returns 22:00 UTC).
        let next = await engine.nextEventStart(after: DT.d("2025-08-12 10:00"), on: sampleDate, policy: policy)
        XCTAssertEqual(next, DT.d("2025-08-12 22:00"))

        // No conflicts inside availability in this dataset
        let conflicts = await engine.conflictingItemsCount(on: sampleDate, policy: policy)
        XCTAssertEqual(conflicts, 0)
    }

    // MARK: - Padding: ensure buffers shrink free time as expected

    func testPadding_reducesFreeTime() async throws {
        let engine = makeEngine(with: sampleEvents())
        var policy = fullDayUTC
        policy.padBefore = 5*60
        policy.padAfter  = 5*60

        let free = await engine.freeWindows(on: sampleDate, minimumMinutes: 0, policy: policy)

        // The first big free block was [01:00–06:30]; with padding, preceding/next busy expand by 5m each,
        // so this window should be [01:05–06:25].
        XCTAssertEqual(free.first?.start, DT.d("2025-08-12 01:05"))
        XCTAssertEqual(free.first?.end,   DT.d("2025-08-12 06:25"))
    }
}
