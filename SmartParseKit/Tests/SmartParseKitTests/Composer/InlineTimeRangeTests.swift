
import XCTest
@testable import SmartParseKit

final class InlineTimeRangeTests: XCTestCase {
    func testWeekdayWithTime() {
        let c = TestUtil.makeEN()
        let now = TestUtil.now(2025,9,11, 9, 0) // Thu
        let r = c.parse("schedule coffee with Ana for 10:00 Tuesday morning", now: now)
        guard let res = r.resolution else { return XCTFail("No resolution") }
        guard case .instant(let date, _, _, _) = res else { return XCTFail("Expected instant") }
        let comp = TestUtil.comps(date)
        XCTAssertEqual(comp.weekday, 3) // Tuesday
        XCTAssertEqual(comp.hour, 10)
        XCTAssertEqual(comp.minute, 0)
    }

    func testPivotChoosesRightmostAfterAt() {
        let c = TestUtil.makeEN()
        let now = TestUtil.now(2025,9,11, 9, 0)
        let r = c.parse("dinner with parents tonight 8pm at 7pm", now: now)
        guard let res = r.resolution else { return XCTFail("No resolution") }
        guard case .instant(let date, _, _, _) = res else { return XCTFail("Expected instant") }
        let comp = TestUtil.comps(date)
        XCTAssertEqual(comp.hour, 19) // 7pm
    }
    
    func testWeekdayWithTimeRange() {
        let c = TestUtil.makeEN()
        let now = TestUtil.now(2025,9,11, 9, 0)
        let r = c.parse("team meeting Wed 8am to 9am", now: now)
        guard let res = r.resolution else { return XCTFail("No resolution") }
        switch res {
        case .instant(let date, _, _, let duration):
            let comp = TestUtil.comps(date)
            XCTAssertEqual(comp.year, 2025); XCTAssertEqual(comp.month, 9); XCTAssertEqual(comp.day, 17)
            XCTAssertEqual(comp.hour, 8); XCTAssertEqual(comp.minute, 0)
            XCTAssertEqual(duration, 3600)
        case .range(let dateInterval, _, _):
            return XCTFail("Expected instant")
        }
    }
}
