//
//  RecurrenceHelperTests.swift
//  ZunloTests
//
//  Created by Marcio Garcia on 7/6/25.
//

import XCTest
@testable import Zunlo

final class RecurrenceHelperTests: XCTestCase {
    let calendar = Calendar.current

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return calendar.date(from: comps)!
    }

    func testDailyRecurrence() {
        let start = date(2024, 7, 1)
        let rule = RecurrenceRule(id: UUID(), eventId: UUID(),
                                  freq: "daily",
                                  interval: 1, byWeekday: nil, byMonthday: nil, byMonth: nil,
                                  until: nil, count: 3,
                                  createdAt: Date(), updatedAt: Date())
        let range = date(2024, 7, 1)...date(2024, 7, 5)
        let result = RecurrenceHelper.generateRecurrenceDates(start: start, rule: rule, within: range)
        XCTAssertEqual(result, [date(2024,7,1), date(2024,7,2), date(2024,7,3)])
    }

    func testWeeklyRecurrence_MondayWednesday() {
        let start = date(2024, 7, 1) // Monday
        let rule = RecurrenceRule(id: UUID(), eventId: UUID(), freq: "weekly",
                                  interval: 1, byWeekday: [2,4],
                                  byMonthday: nil, byMonth: nil,
                                  until: nil, count: 4,
                                  createdAt: Date(), updatedAt: Date())
        let range = date(2024, 7, 1)...date(2024, 7, 14)
        let result = RecurrenceHelper.generateRecurrenceDates(start: start, rule: rule, within: range)
        // July 1 (Mon), July 3 (Wed), July 8 (Mon), July 10 (Wed)
        XCTAssertEqual(result, [date(2024,7,1), date(2024,7,3), date(2024,7,8), date(2024,7,10)])
    }

    func testMonthlyRecurrence_31st() {
        let start = date(2024, 1, 31)
        let rule = RecurrenceRule(id: UUID(), eventId: UUID(), freq: "monthly",
                                  interval: 1,
                                  byWeekday: nil, byMonthday: [31], byMonth: nil,
                                  until: nil, count: 3,
                                  createdAt: Date(), updatedAt: Date())
        let range = date(2024, 1, 1)...date(2024, 5, 31)
        let result = RecurrenceHelper.generateRecurrenceDates(start: start, rule: rule, within: range)
        // Only Jan 31, Mar 31, May 31 (Feb and Apr don't have 31st)
        XCTAssertEqual(result, [date(2024,1,31), date(2024,3,31), date(2024,5,31)])
    }

    func testRecurrenceUntilDate() {
        let start = date(2024, 7, 1)
        let until = date(2024, 7, 3)
        let rule = RecurrenceRule(id: UUID(), eventId: UUID(), freq: "daily",
                                  interval: 1, byWeekday: nil, byMonthday: nil, byMonth: nil, until: until, count: nil, createdAt: Date(), updatedAt: Date())
        let range = date(2024, 7, 1)...date(2024, 7, 10)
        let result = RecurrenceHelper.generateRecurrenceDates(start: start, rule: rule, within: range)
        XCTAssertEqual(result, [date(2024,7,1), date(2024,7,2), date(2024,7,3)])
    }

    func testRecurrenceOutsideRange() {
        let start = date(2024, 7, 1)
        let rule = RecurrenceRule(id: UUID(), eventId: UUID(),
                                  freq: "daily", interval: 1,
                                  byWeekday: nil, byMonthday: nil, byMonth: nil, until: nil, count: 3, createdAt: Date(), updatedAt: Date())
        let range = date(2024, 7, 5)...date(2024, 7, 10)
        let result = RecurrenceHelper.generateRecurrenceDates(start: start, rule: rule, within: range)
        // None of the first 3 are in range
        XCTAssertEqual(result, [])
    }
}
