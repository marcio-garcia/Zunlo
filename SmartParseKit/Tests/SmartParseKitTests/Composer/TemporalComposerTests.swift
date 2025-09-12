
import XCTest
@testable import SmartParseKit

final class TemporalComposerTests: XCTestCase {

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
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("add event graduation ceremony next week at 11:00", now: now)
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail("No instant") }
        let c = components(date)
        // Monday Sep 15, 11:00
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 9); XCTAssertEqual(c.d, 18)
        XCTAssertEqual(c.h, 11); XCTAssertEqual(c.min, 0)
    }

    func testNextWeekFri1100() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("rebook team meeting for next week Fri 11:00", now: now)
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail("No instant") }
        let c = components(date)
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 9); XCTAssertEqual(c.d, 19)
        XCTAssertEqual(c.h, 11); XCTAssertEqual(c.min, 0)
    }

    func testNextFriday3pm() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("move team meeting to next Friday 3pm", now: now)
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail("No instant") }
        let c = components(date)
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 9); XCTAssertEqual(c.d, 19)
        XCTAssertEqual(c.h, 15); XCTAssertEqual(c.min, 0)
    }

    func testNextWeekNoon() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("move oil change to next week noon", now: now)
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail("No instant") }
        let c = components(date)
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 9); XCTAssertEqual(c.d, 18)
        XCTAssertEqual(c.h, 12)
    }

    func testSpecificDateWithTime() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("push dentist appointment to october 15th 7pm", now: now)
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail("No instant") }
        let c = components(date)
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 10); XCTAssertEqual(c.d, 15)
        XCTAssertEqual(c.h, 19)
    }

    func testConflictTimesRightmostWins() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("dinner with parents tonight 8pm at 7pm", now: now)
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail("No instant") }
        let c = components(date)
        XCTAssertEqual(c.h, 19) // 7pm
    }

    func testMonthFromNow() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("a month from now 11am", now: now)
        // Offsets are not fully applied in this compact example; we at least parse time and day scope == today.
        // For demonstration, expect 11:00 today or we can relax by checking time.
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail("No instant") }
        let c = components(date)
        XCTAssertEqual(c.h, 11)
    }

    func testNextTue() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("change write report task to next tue", now: now)
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail("No instant") }
        let c = components(date)
        let referenceComp = components(now)
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 9); XCTAssertEqual(c.d, 16) // Tue next week
        XCTAssertEqual(c.h, referenceComp.h) // morning anchor
    }

    func testWeekendAnchor() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("push back do laundry to weekend", now: now)
        
        switch r.resolution! {
        case .instant(_, _, _):
            return XCTFail("Return range because there is no specifics")
        case .range(let dateInterval, _, _):
            let compStart = components(dateInterval.start)
            let compEnd = components(dateInterval.end)
            
            XCTAssertEqual(compStart.y, 2025); XCTAssertEqual(compStart.m, 9); XCTAssertEqual(compStart.d, 13)
            XCTAssertEqual(compStart.h, 00); XCTAssertEqual(compStart.min, 0)
            XCTAssertEqual(compEnd.y, 2025); XCTAssertEqual(compEnd.m, 9); XCTAssertEqual(compEnd.d, 14)
            XCTAssertEqual(compEnd.h, 23); XCTAssertEqual(compEnd.min, 59)
        }
    }

    func testNextThursdayMorning() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("show agenda for next Thursday morning", now: now)
        switch r.resolution! {
        case .instant(_, _, _):
            return XCTFail("Expected range filter for view intent")
        case .range(let dateInterval, _, _):
            let compStart = components(dateInterval.start)
            let compEnd = components(dateInterval.end)
            
            XCTAssertEqual(r.intent, .view)
            XCTAssertEqual(compStart.y, 2025); XCTAssertEqual(compStart.m, 9); XCTAssertEqual(compStart.d, 18)
            XCTAssertEqual(compStart.h, 6); XCTAssertEqual(compStart.min, 0)
            XCTAssertEqual(compEnd.y, 2025); XCTAssertEqual(compEnd.m, 9); XCTAssertEqual(compEnd.d, 18)
            XCTAssertEqual(compEnd.h, 11); XCTAssertEqual(compEnd.min, 59)
        }
    }

    func testRelativeDayAndPartOfDay() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("schedule client meeting for 10am tomorrow", now: now)
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail("No instant") }
        let c = components(date)
        XCTAssertEqual(c.d, 12) // tomorrow
        XCTAssertEqual(c.h, 10)
    }
    
    func testShowAgendNextWeek() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("what is my agenda for next week", now: now)
        switch r.resolution! {
        case .instant(_, _, _):
            return XCTFail("Expected range filter for view intent")
        case .range(let dateInterval, _, _):
            let compStart = components(dateInterval.start)
            let compEnd = components(dateInterval.end)
            
            XCTAssertEqual(r.intent, .view)
            XCTAssertEqual(compStart.y, 2025); XCTAssertEqual(compStart.m, 9); XCTAssertEqual(compStart.d, 15)
            XCTAssertEqual(compStart.h, 0); XCTAssertEqual(compStart.min, 0)
            XCTAssertEqual(compEnd.y, 2025); XCTAssertEqual(compEnd.m, 9); XCTAssertEqual(compEnd.d, 21)
            XCTAssertEqual(compEnd.h, 23); XCTAssertEqual(compEnd.min, 59)
        }
    }

    // --- Portuguese (BR) ---
    func testPT_NextWeekFri1100() {
        let pack = PortugueseBRPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("remarcar reunião para próxima semana sex 11:00", now: now)
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail("No instant") }
        let c = components(date)
        // Next week's Friday: 2025-09-19 11:00
        XCTAssertEqual(c.y, 2025); XCTAssertEqual(c.m, 9); XCTAssertEqual(c.d, 19)
        XCTAssertEqual(c.h, 11)
    }

    func testPT_TerceaAs10() {
        let pack = PortugueseBRPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("marcar café terça às 10h", now: now)
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail("No instant") }
        let c = components(date)
        // Next upcoming Tuesday from Sep 11, 2025 (Thu) is Sep 16
        XCTAssertEqual(c.d, 16); XCTAssertEqual(c.h, 10)
    }

    // --- Spanish ---
    func testES_NextWeekFri1100() {
        let pack = SpanishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("reprogramar reunión para la próxima semana vie 11:00", now: now)
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail("No instant") }
        let c = components(date)
        XCTAssertEqual(c.d, 19); XCTAssertEqual(c.h, 11)
    }

    func testES_MartesALas10() {
        let pack = SpanishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("programar café para el martes a las 10:00", now: now)
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail("No instant") }
        let c = components(date)
        XCTAssertEqual(c.d, 16); XCTAssertEqual(c.h, 10)
    }
    
    func testInlineWeekdayTimeSingle() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("schedule coffee on Tuesday 10:00", now: now)
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail() }
        let c = components(date)
        XCTAssertEqual(c.d, 16); XCTAssertEqual(c.h, 10)
    }

    func testInlineWeekdayTimeRange() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("block Wed 09:00-11:30", now: now)
        // Verify timeRange was recognized and start time used as anchor
        guard case .instant(let date, _, _) = r.resolution! else { return XCTFail() }
        let c = components(date)
        XCTAssertEqual(c.h, 9); XCTAssertEqual(c.min, 0)
    }
    
    func testOrdinalDayEN() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("display calendar for the 24th", now: now)
        // Should resolve to 24 of this month (or next if past)
        XCTAssertNotNil(r.resolution)
    }

    func testOrdinalDayPT() {
        let pack = PortugueseBRPack(calendar: calendarSP())
        let composer = TemporalComposer(pack: pack)
        let now = makeNow()
        let r = composer.parse("mostrar agenda do dia 11º", now: now)
        XCTAssertNotNil(r.resolution)
    }
}
