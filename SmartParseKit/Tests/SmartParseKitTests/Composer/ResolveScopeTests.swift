
import XCTest
@testable import SmartParseKit

final class ResolveScopeTests: XCTestCase {
    func testNextWeekFri1100PicksNextFriday() {
        let c = TestUtil.makeEN()
        let now = TestUtil.now(2025,9,11, 9, 0) // Thu
        let r = c.parse("rebook team meeting for next week Fri 11:00", now: now)
        guard let res = r.resolution else { return XCTFail("No resolution") }
        guard case .instant(let date, _, _) = res else { return XCTFail("Expected instant") }
        let comp = TestUtil.comps(date)
        XCTAssertEqual(comp.weekday, 6) // Friday
        XCTAssertEqual(comp.hour, 11)
        XCTAssertEqual(comp.day, 19)    // Next week's Friday is Sept 19, 2025
    }

    func testChangeToNoonToday() {
        let c = TestUtil.makeEN()
        let now = TestUtil.now(2025,9,11, 9, 0)
        let r = c.parse("change event team standup meeting to noon", now: now)
        guard let res = r.resolution else { return XCTFail("No resolution") }
        guard case .instant(let date, _, _) = res else { return XCTFail("Expected instant") }
        let comp = TestUtil.comps(date)
        XCTAssertEqual(comp.day, 11)
        XCTAssertEqual(comp.hour, 12)
    }
}
