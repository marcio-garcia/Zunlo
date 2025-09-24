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
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("add event graduation ceremony next week at 11:00", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 30, length: 9), text: "next week", kind: .relativeWeek(.nextWeek(count: 1))),
            TemporalToken(range: NSRange(location: 43, length: 5), text: "11:00", kind: .absoluteTime(DateComponents(hour: 11, minute: 0)))
        ])
    }
    
    func testNextFriday() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("move game to next Friday", now: now, pack: pack)

        let temporalRetult = result.0

        XCTAssertEqual(temporalRetult[0].text, "next Friday")
        XCTAssertEqual(temporalRetult[0].kind, .weekday(dayIndex: 6, modifier: .next))
    }

    func testNextWeekFri1100() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("rebook team meeting for next week Fri 11:00", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 24, length: 9), text: "next week", kind: .relativeWeek(.nextWeek(count: 1))),
            TemporalToken(range: NSRange(location: 34, length: 3), text: "Fri", kind: .weekday(dayIndex: 6, modifier: nil)),
            TemporalToken(range: NSRange(location: 38, length: 5), text: "11:00", kind: .absoluteTime(DateComponents(hour: 11, minute: 0)))
        ])
    }

    func testNextFriday3pm() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("move team meeting to next Friday 3pm", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 21, length: 11), text: "next Friday", kind: .weekday(dayIndex: 6, modifier: .next)),
            TemporalToken(range: NSRange(location: 33, length: 3), text: "3pm", kind: .absoluteTime(DateComponents(hour: 15, minute: 0)))
        ])
    }

    func testNextWeekNoon() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("move oil change to next week noon", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 19, length: 9), text: "next week", kind: .relativeWeek(.nextWeek(count: 1))),
            TemporalToken(range: NSRange(location: 29, length: 4), text: "noon", kind: .absoluteTime(DateComponents(hour: 12, minute: 0)))
        ])
    }

    func testSpecificDateWithTime() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("push dentist appointment to october 15th 7pm", now: now, pack: pack)
        
        XCTAssertEqual(result.0[1], TemporalToken(range: NSRange(location: 36, length: 4), text: "15th", kind: .ordinalDay(15)))
        XCTAssertEqual(result.0[2], TemporalToken(range: NSRange(location: 41, length: 3), text: "7pm", kind: .absoluteTime(DateComponents(hour: 19, minute: 0))))

        XCTAssertEqual(result.0[0].range, NSRange(location: 28, length: 16))
        XCTAssertEqual(result.0[0].text, "october 15th 7pm")

        let firstTokenKind = result.0[0].kind
        if case .absoluteDate(let comps) = firstTokenKind {
            XCTAssertEqual(comps.year, 2025); XCTAssertEqual(comps.month, 10); XCTAssertEqual(comps.day, 15)
            XCTAssertEqual(comps.hour, 19); XCTAssertEqual(comps.minute, 0)
        }

    }

    func testConflictTimesRightmostWins() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("dinner with parents tonight 8pm at 7pm", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 20, length: 7), text: "tonight", kind: .relativeDay(.tonight)),
            TemporalToken(range: NSRange(location: 28, length: 3), text: "8pm", kind: .absoluteTime(DateComponents(hour: 20, minute: 0))),
            TemporalToken(range: NSRange(location: 35, length: 3), text: "7pm", kind: .absoluteTime(DateComponents(hour: 19, minute: 0)))
        ])
    }

    func testMonthFromNow() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("a month from now 11am", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 0, length: 16), text: "a month from now", kind: .durationOffset(value: 1, unit: .month, mode: .fromNow)),
            TemporalToken(range: NSRange(location: 17, length: 4), text: "11am", kind: .absoluteTime(DateComponents(hour: 11, minute: 0)))
        ])
    }

    func testNextTue() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("change write report task to next tue", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 28, length: 8), text: "next tue", kind: .weekday(dayIndex: 3, modifier: .next))
        ])
    }

    func testWeekendAnchor() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("push back do laundry to weekend", now: now, pack: pack)

        let temporalRetult = result.0
        XCTAssertEqual(temporalRetult, [
            TemporalToken(range: NSRange(location: 24, length: 7), text: "weekend", kind: .weekend(.thisWeek))
        ])
    }

    func testNextThursdayMorning() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("show agenda for next Thursday morning", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 16, length: 13), text: "next Thursday", kind: .weekday(dayIndex: 5, modifier: .next)),
            TemporalToken(range: NSRange(location: 30, length: 7), text: "morning", kind: .partOfDay(.morning))
        ])
    }

    func testRelativeDayAndPartOfDay() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("schedule client meeting for 10am tomorrow", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 28, length: 4), text: "10am", kind: .absoluteTime(DateComponents(hour: 10, minute: 0))),
            TemporalToken(range: NSRange(location: 33, length: 8), text: "tomorrow", kind: .relativeDay(.tomorrow))
        ])
    }

    func testShowAgendNextWeek() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("what is my agenda for next week", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 22, length: 9), text: "next week", kind: .relativeWeek(.nextWeek(count: 1)))
        ])
    }
    
    func testRelativeDayAndTimeWithH() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("add movie today 20h", now: now, pack: pack)

        let temporalRetult = result.0
        XCTAssertEqual(temporalRetult[0].text, "today"); XCTAssertEqual(temporalRetult[0].kind, .relativeDay(.today));
        XCTAssertEqual(temporalRetult[1].text, "20h"); XCTAssertEqual(temporalRetult[1].kind, .absoluteTime(DateComponents(hour: 20, minute: 0)));
    }

    func testWeekday() async throws {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("reschedule submit assignment task to Friday", now: now, pack: pack)

        XCTAssertEqual(result.0[0].text, "Friday");
        XCTAssertEqual(result.0[0].kind, .weekday(dayIndex: 6, modifier: nil))
    }
    
    // --- Portuguese (BR) ---
    func testPT_NextWeekFri1100() {
        let pack = PortugueseBRPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("remarcar reunião para próxima semana sex 11:00", now: now, pack: pack)

        XCTAssertTrue(result.0.contains { token in
            if case .relativeWeek(.nextWeek(count: 1)) = token.kind, token.text == "próxima semana" {
                return true
            }
            return false
        })
        XCTAssertTrue(result.0.contains { token in
            if case .weekday(dayIndex: 6, modifier: nil) = token.kind, token.text == "sex" {
                return true
            }
            return false
        })
        XCTAssertTrue(result.0.contains { token in
            if case .absoluteTime(let components) = token.kind, components.hour == 11 {
                return true
            }
            return false
        })
    }

    func testPT_TercaAs10() {
        let pack = PortugueseBRPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("marcar café terça às 10h", now: now, pack: pack)

        XCTAssertTrue(result.0.contains { token in
            if case .weekday(dayIndex: 3, modifier: nil) = token.kind {
                return true
            }
            return false
        })
        XCTAssertTrue(result.0.contains { token in
            if case .absoluteTime(let components) = token.kind, components.hour == 10 {
                return true
            }
            return false
        })
    }
    
    func testPT_DaquiAUmMes() {
        let pack = PortugueseBRPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("daqui a um mês às 11h", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 0, length: 14), text: "daqui a um mês", kind: .durationOffset(value: 1, unit: .month, mode: .fromNow)),
            TemporalToken(range: NSRange(location: 18, length: 3), text: "11h", kind: .absoluteTime(DateComponents(hour: 11, minute: 0)))
        ])
    }
    
    func testPT_NextFriday() {
        let pack = PortugueseBRPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("Mova jogo para próxima sexta", now: now, pack: pack)

        let temporalRetult = result.0
        XCTAssertEqual(temporalRetult[0].text, "próxima sexta")
        XCTAssertEqual(temporalRetult[0].kind, .weekday(dayIndex: 6, modifier: .next))
    }

    func testPT_TuesdayAfternoon() {
        let pack = PortugueseBRPack(calendar: TestUtil.calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("Criar reunião terça `a tarde", now: now, pack: pack)

        let temporalRetult = result.0
        XCTAssertEqual(temporalRetult[0].text, "terça")
        XCTAssertEqual(temporalRetult[0].kind, .weekday(dayIndex: 3, modifier: .none))
        
        XCTAssertEqual(temporalRetult[1].text, "tarde")
        XCTAssertEqual(temporalRetult[1].kind, .partOfDay(.afternoon))
    }
    
    func testPT_OrdinalDayAndTimeRange() {
        let pack = PortugueseBRPack(calendar: TestUtil.calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("Crie evento standup 25th 9-10:30am", now: now, pack: pack)

        let temporalRetult = result.0
        let metadataResult = result.1

        XCTAssertEqual(metadataResult.tokens.count, 0)
        
        XCTAssertEqual(temporalRetult[0].text, "25th")
        XCTAssertEqual(temporalRetult[0].kind, .ordinalDay(25))
        
        XCTAssertEqual(temporalRetult[1].text, "9-10:30am")
        XCTAssertEqual(temporalRetult[1].kind, .timeRange(start: DateComponents(hour: 9, minute: 0), end: DateComponents(hour: 10, minute: 30)))
    }
    
    // --- Spanish ---
    func testES_NextWeekFri1100() {
        let pack = SpanishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("reprogramar reunión para la próxima semana vie 11:00", now: now, pack: pack)

        let temporalRetult = result.0
        
        XCTAssertTrue(temporalRetult.contains { token in
            if case .relativeWeek(.nextWeek(count: 1)) = token.kind {
                return true
            }
            return false
        })
        XCTAssertTrue(temporalRetult.contains { token in
            if case .weekday(dayIndex: 6, modifier: nil) = token.kind {
                return true
            }
            return false
        })
        XCTAssertTrue(temporalRetult.contains { token in
            if case .absoluteTime(let components) = token.kind, components.hour == 11 {
                return true
            }
            return false
        })
    }

    func testES_MartesALas10() {
        let pack = SpanishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("programar café para el martes a las 10:00", now: now, pack: pack)

        XCTAssertTrue(result.0.contains { token in
            if case .weekday(dayIndex: 3, modifier: nil) = token.kind {
                return true
            }
            return false
        })
        XCTAssertTrue(result.0.contains { token in
            if case .absoluteTime(let components) = token.kind, components.hour == 10 {
                return true
            }
            return false
        })
    }

    func testES_DeAquiAUnMes() {
        let pack = SpanishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("de aquí a un mes a las 11h", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 0, length: 16), text: "de aquí a un mes", kind: .durationOffset(value: 1, unit: .month, mode: .fromNow)),
            TemporalToken(range: NSRange(location: 23, length: 3), text: "11h", kind: .absoluteTime(DateComponents(hour: 11, minute: 0)))
        ])
    }

    func testInlineWeekdayTimeSingle() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("schedule coffee on Tuesday 10:00", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 19, length: 7), text: "Tuesday", kind: .weekday(dayIndex: 3, modifier: nil)),
            TemporalToken(range: NSRange(location: 27, length: 5), text: "10:00", kind: .absoluteTime(DateComponents(hour: 10, minute: 0)))
        ])
    }

    func testInlineWeekdayTimeRange() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("block Wed 09:00-11:30", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 6, length: 3), text: "Wed", kind: .weekday(dayIndex: 4, modifier: nil)),
            TemporalToken(range: NSRange(location: 10, length: 11), text: "09:00-11:30",
                         kind: .timeRange(start: DateComponents(hour: 9, minute: 0),
                                        end: DateComponents(hour: 11, minute: 30)))
        ])
    }

    func testOrdinalDayEN() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("display calendar for the 24th", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 21, length: 8), text: "the 24th", kind: .ordinalDay(24))
        ])
    }
    
    func testOrdinalDayNextMonth() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("display calendar for the 10th", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 21, length: 8), text: "the 10th", kind: .ordinalDay(10))
        ])
    }

    func testOrdinalDayPT() {
        let pack = PortugueseBRPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("mostrar agenda do dia 11º", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 18, length: 7), text: "dia 11º", kind: .ordinalDay(11))
        ])
    }

    // Test cases focusing on parser output only (no metadata extraction)
    func testEmptyInput() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("", now: now, pack: pack)

        XCTAssertLessThanOrEqual(result.1.confidence, 0.1)
        XCTAssertEqual(result.0.count, 0)
    }

    func testSimpleTimeOnly() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("meeting at 3pm", now: now, pack: pack)

        XCTAssertEqual(result.0, [
            TemporalToken(range: NSRange(location: 11, length: 3), text: "3pm", kind: .absoluteTime(DateComponents(hour: 15, minute: 0)))
        ])
    }

    func testTomorrowOnly() {
        let pack = EnglishPack(calendar: calendarSP())
        let composer = TemporalComposer(prefs: Preferences(calendar: calendarSP()))
        let now = makeNow()
        let result = composer.parse("call tomorrow", now: now, pack: pack)

        let temporalRetult = result.0
        let metadataResult = result.1
        XCTAssertEqual(metadataResult.title, "call")
        XCTAssertEqual(temporalRetult, [
            TemporalToken(range: NSRange(location: 5, length: 8), text: "tomorrow", kind: .relativeDay(.tomorrow))
        ])
    }
}
