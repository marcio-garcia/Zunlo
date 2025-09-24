import XCTest
@testable import SmartParseKit

final class TemporalTokenInterpreterTests: XCTestCase {

    private func makeNow() -> Date {
        // 2025-09-11 10:00:00 -03:00 (America/Sao_Paulo)
        var comps = DateComponents()
        comps.year = 2025; comps.month = 9; comps.day = 11
        comps.hour = 10; comps.minute = 0; comps.second = 0
        comps.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func calendarSP() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        cal.firstWeekday = 2 // Monday
        cal.locale = nil
        return cal
    }

    private func components(_ date: Date) -> (y:Int,m:Int,d:Int,h:Int,min:Int) {
        let cal = calendarSP()
        let c = cal.dateComponents([.year,.month,.day,.hour,.minute], from: date)
        return (c.year!, c.month!, c.day!, c.hour!, c.minute!)
    }

    func testNextWeekAt11() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 30, length: 9), text: "next week", kind: .relativeWeek(.nextWeek(count: 1))),
            TemporalToken(range: NSRange(location: 43, length: 5), text: "11:00", kind: .absoluteTime(DateComponents(hour: 11, minute: 0)))
        ]

        let context = interpreter.interpret(tokens)
        let c = components(context.finalDate)

        XCTAssertFalse(context.isRangeQuery)
        // Monday Sep 15, 11:00 (next week's Monday)
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 9); XCTAssertEqual(c.d, 18)
        XCTAssertEqual(c.h, 11); XCTAssertEqual(c.min, 0)
    }

    func testNextWeekFri1100() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 28, length: 9), text: "next week", kind: .relativeWeek(.nextWeek(count: 1))),
            TemporalToken(range: NSRange(location: 38, length: 3), text: "Fri", kind: .weekday(dayIndex: 6, modifier: nil)),
            TemporalToken(range: NSRange(location: 42, length: 5), text: "11:00", kind: .absoluteTime(DateComponents(hour: 11, minute: 0)))
        ]

        let context = interpreter.interpret(tokens)
        let c = components(context.finalDate)

        XCTAssertFalse(context.isRangeQuery)
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 9); XCTAssertEqual(c.d, 19)
        XCTAssertEqual(c.h, 11); XCTAssertEqual(c.min, 0)
    }

    func testNextFriday3pm() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 25, length: 12), text: "next Friday", kind: .weekday(dayIndex: 6, modifier: .next)),
            TemporalToken(range: NSRange(location: 38, length: 3), text: "3pm", kind: .absoluteTime(DateComponents(hour: 15, minute: 0)))
        ]

        let context = interpreter.interpret(tokens)
        let c = components(context.finalDate)

        XCTAssertFalse(context.isRangeQuery)
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 9); XCTAssertEqual(c.d, 19)
        XCTAssertEqual(c.h, 15); XCTAssertEqual(c.min, 0)
    }

    func testNextWeekNoon() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 22, length: 9), text: "next week", kind: .relativeWeek(.nextWeek(count: 1))),
            TemporalToken(range: NSRange(location: 32, length: 4), text: "noon", kind: .partOfDay(.noon))
        ]

        let context = interpreter.interpret(tokens)
        let c = components(context.finalDate)

        XCTAssertFalse(context.isRangeQuery)
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 9); XCTAssertEqual(c.d, 18)
        XCTAssertEqual(c.h, 12)
    }

    func testSpecificDateWithTime() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 32, length: 12), text: "october 15th", kind: .absoluteDate(DateComponents(month: 10, day: 15))),
            TemporalToken(range: NSRange(location: 45, length: 3), text: "7pm", kind: .absoluteTime(DateComponents(hour: 19, minute: 0)))
        ]

        let context = interpreter.interpret(tokens)
        let c = components(context.finalDate)

        XCTAssertFalse(context.isRangeQuery)
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 10); XCTAssertEqual(c.d, 15)
        XCTAssertEqual(c.h, 19)
    }

    func testConflictTimesRightmostWins() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 21, length: 7), text: "tonight", kind: .relativeDay(.tonight)),
            TemporalToken(range: NSRange(location: 29, length: 3), text: "8pm", kind: .absoluteTime(DateComponents(hour: 20, minute: 0))),
            TemporalToken(range: NSRange(location: 36, length: 3), text: "7pm", kind: .absoluteTime(DateComponents(hour: 19, minute: 0)))
        ]

        let context = interpreter.interpret(tokens)
        let c = components(context.finalDate)

        XCTAssertFalse(context.isRangeQuery)
        XCTAssertEqual(c.h, 19) // 7pm (rightmost wins)
        XCTAssertGreaterThan(context.conflicts.count, 0) // Should detect conflict
    }

    func testMonthFromNow() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 0, length: 15), text: "a month from now", kind: .durationOffset(value: 1, unit: .month, mode: .fromNow)),
            TemporalToken(range: NSRange(location: 16, length: 4), text: "11am", kind: .absoluteTime(DateComponents(hour: 11, minute: 0)))
        ]

        let context = interpreter.interpret(tokens)
        let c = components(context.finalDate)

        XCTAssertFalse(context.isRangeQuery)
        XCTAssertEqual(c.h, 11)
    }

    func testNextTue() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 32, length: 8), text: "next tue", kind: .weekday(dayIndex: 3, modifier: .next))
        ]

        let context = interpreter.interpret(tokens)
        let c = components(context.finalDate)
        let referenceComp = components(now)

        XCTAssertFalse(context.isRangeQuery)
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 9); XCTAssertEqual(c.d, 16) // Tue next week
        XCTAssertEqual(c.h, referenceComp.h) // Same time as reference
    }

    func testWeekendAnchor() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 29, length: 7), text: "weekend", kind: .weekend(.thisWeek))
        ]

        let context = interpreter.interpret(tokens)

        XCTAssertTrue(context.isRangeQuery)
        XCTAssertNotNil(context.dateRange)

        let startComp = components(context.dateRange!.start)
        let endComp = components(context.dateRange!.end)

        XCTAssertEqual(startComp.y, 2025); XCTAssertEqual(startComp.m, 9); XCTAssertEqual(startComp.d, 13)
        XCTAssertEqual(startComp.h, 0); XCTAssertEqual(startComp.min, 0)
        XCTAssertEqual(endComp.y, 2025); XCTAssertEqual(endComp.m, 9); XCTAssertEqual(endComp.d, 14)
        XCTAssertEqual(endComp.h, 23); XCTAssertEqual(endComp.min, 59)
    }

    func testNextThursdayMorning() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 16, length: 14), text: "next Thursday", kind: .weekday(dayIndex: 5, modifier: .next)),
            TemporalToken(range: NSRange(location: 31, length: 7), text: "morning", kind: .partOfDay(.morning))
        ]

        let context = interpreter.interpret(tokens)

        XCTAssertTrue(context.isRangeQuery)
        XCTAssertNotNil(context.dateRange)

        let startComp = components(context.dateRange!.start)
        let endComp = components(context.dateRange!.end)

        XCTAssertEqual(startComp.y, 2025); XCTAssertEqual(startComp.m, 9); XCTAssertEqual(startComp.d, 18)
        XCTAssertEqual(startComp.h, 6); XCTAssertEqual(startComp.min, 0)
        XCTAssertEqual(endComp.y, 2025); XCTAssertEqual(endComp.m, 9); XCTAssertEqual(endComp.d, 18)
        XCTAssertEqual(endComp.h, 11); XCTAssertEqual(endComp.min, 59)
    }

    func testRelativeDayAndPartOfDay() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 32, length: 8), text: "tomorrow", kind: .relativeDay(.tomorrow)),
            TemporalToken(range: NSRange(location: 28, length: 4), text: "10am", kind: .absoluteTime(DateComponents(hour: 10, minute: 0)))
        ]

        let context = interpreter.interpret(tokens)
        let c = components(context.finalDate)

        XCTAssertFalse(context.isRangeQuery)
        XCTAssertEqual(c.d, 12) // tomorrow
        XCTAssertEqual(c.h, 10)
    }

    func testShowAgendNextWeek() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 25, length: 9), text: "next week", kind: .relativeWeek(.nextWeek(count: 1)))
        ]

        let context = interpreter.interpret(tokens)

        XCTAssertTrue(context.isRangeQuery)
        XCTAssertNotNil(context.dateRange)

        let startComp = components(context.dateRange!.start)
        let endComp = components(context.dateRange!.end)

        XCTAssertEqual(startComp.y, 2025); XCTAssertEqual(startComp.m, 9); XCTAssertEqual(startComp.d, 15)
        XCTAssertEqual(startComp.h, 0); XCTAssertEqual(startComp.min, 0)
        XCTAssertEqual(endComp.y, 2025); XCTAssertEqual(endComp.m, 9); XCTAssertEqual(endComp.d, 21)
        XCTAssertEqual(endComp.h, 23); XCTAssertEqual(endComp.min, 59)
    }

    func testInlineWeekdayTimeSingle() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 20, length: 7), text: "Tuesday", kind: .weekday(dayIndex: 3, modifier: nil)),
            TemporalToken(range: NSRange(location: 28, length: 5), text: "10:00", kind: .absoluteTime(DateComponents(hour: 10, minute: 0)))
        ]

        let context = interpreter.interpret(tokens)
        let c = components(context.finalDate)

        XCTAssertFalse(context.isRangeQuery)
        XCTAssertEqual(c.d, 16); XCTAssertEqual(c.h, 10)
    }

    func testInlineWeekdayTimeRange() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 6, length: 3), text: "Wed", kind: .weekday(dayIndex: 4, modifier: nil)),
            TemporalToken(range: NSRange(location: 10, length: 11), text: "09:00-11:30",
                         kind: .timeRange(start: DateComponents(hour: 9, minute: 0),
                                        end: DateComponents(hour: 11, minute: 30)))
        ]

        let context = interpreter.interpret(tokens)
        let c = components(context.finalDate)

        XCTAssertFalse(context.isRangeQuery)
        XCTAssertEqual(c.h, 9); XCTAssertEqual(c.min, 0)
    }

    func testOrdinalDay() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 25, length: 7), text: "the 24th", kind: .ordinalDay(24))
        ]

        let context = interpreter.interpret(tokens)
        let c = components(context.finalDate)

        XCTAssertFalse(context.isRangeQuery)
        // Should resolve to 24 of this month (or next if past)
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 9); XCTAssertEqual(c.d, 24)
        XCTAssertEqual(c.h, 10); XCTAssertEqual(c.min, 0) // same time as reference
    }

    func testOrdinalDayNextMonth() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 25, length: 7), text: "the 10th", kind: .ordinalDay(10))
        ]

        let context = interpreter.interpret(tokens)
        let c = components(context.finalDate)

        XCTAssertFalse(context.isRangeQuery)
        // Should resolve to 24 of this month (or next if past)
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 10); XCTAssertEqual(c.d, 10)
        XCTAssertEqual(c.h, 10); XCTAssertEqual(c.min, 0) // same time as reference
    }

    func testEmptyTokens() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let context = interpreter.interpret([])

        XCTAssertEqual(context.finalDate, now)
        XCTAssertEqual(context.confidence, 0.0)
        XCTAssertEqual(context.resolvedTokens.count, 0)
    }

    func testAbsoluteTimeOnly() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 0, length: 4), text: "3pm", kind: .absoluteTime(DateComponents(hour: 15, minute: 0)))
        ]

        let context = interpreter.interpret(tokens)
        let c = components(context.finalDate)

        XCTAssertFalse(context.isRangeQuery)
        XCTAssertEqual(c.h, 15); XCTAssertEqual(c.min, 0)
        XCTAssertEqual(c.d, 11) // Same day as reference
    }

    func testTomorrowOnly() {
        let calendar = calendarSP()
        let now = makeNow()
        let interpreter = TemporalTokenInterpreter(calendar: calendar, referenceDate: now)

        let tokens = [
            TemporalToken(range: NSRange(location: 0, length: 8), text: "tomorrow", kind: .relativeDay(.tomorrow))
        ]

        let context = interpreter.interpret(tokens)

        // For relative like "tomorrow" with no specific time, it is considered as a range
        // for the cases like "my agenda for tomorrow"
        XCTAssertTrue(context.isRangeQuery)
        XCTAssertNotNil(context.dateRange)

        let startComp = components(context.dateRange!.start)
        let endComp = components(context.dateRange!.end)

        XCTAssertEqual(startComp.y, 2025); XCTAssertEqual(startComp.m, 9); XCTAssertEqual(startComp.d, 12)
        XCTAssertEqual(startComp.h, 0); XCTAssertEqual(startComp.min, 0)
        XCTAssertEqual(endComp.y, 2025); XCTAssertEqual(endComp.m, 9); XCTAssertEqual(endComp.d, 12)
        XCTAssertEqual(endComp.h, 23); XCTAssertEqual(endComp.min, 59)
    }
}
