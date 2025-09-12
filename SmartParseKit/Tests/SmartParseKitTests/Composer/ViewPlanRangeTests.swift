
import XCTest
@testable import SmartParseKit

final class ViewPlanRangeTests: XCTestCase {
    func testAgendaNextThursdayMorningIsRange() {
        let c = TestUtil.makeEN()
        let now = TestUtil.now(2025,9,11, 9, 0) // Thu Sep 11, 2025
        let r = c.parse("show agenda for next Thursday morning", now: now)
        guard let res = r.resolution else { return XCTFail("No resolution") }
        guard case .range(let interval, _, _) = res else { return XCTFail("Expected range") }
        let compsStart = TestUtil.comps(interval.start)
        XCTAssertEqual(compsStart.year, 2025)
        XCTAssertEqual(compsStart.month, 9)
        XCTAssertEqual(compsStart.day, 18)
        XCTAssertEqual(compsStart.hour, 8) // morning slice starts at 08:00
    }

    func testBareWeekPlansThisWeekRange() {
        let c = TestUtil.makeEN()
        let now = TestUtil.now(2025,9,11, 9, 0)
        let r = c.parse("show agenda for this week", now: now)
        guard let res = r.resolution else { return XCTFail("No resolution") }
        guard case .range(let interval, _, _) = res else { return XCTFail("Expected range") }
        // Start of week is Monday (prefs.startOfWeek = 2)
        let comps = TestUtil.comps(interval.start)
        XCTAssertEqual(comps.weekday, 2)
        XCTAssertEqual(interval.duration, 7*24*3600, accuracy: 60)
    }
}
