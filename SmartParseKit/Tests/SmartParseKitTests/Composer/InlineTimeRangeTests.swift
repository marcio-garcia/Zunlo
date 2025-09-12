
import XCTest
@testable import SmartParseKit

final class InlineTimeRangeTests: XCTestCase {
    func testWeekdayWithTime() {
        let c = TestUtil.makeEN()
        let now = TestUtil.now(2025,9,11, 9, 0) // Thu
        let r = c.parse("schedule coffee with Ana for 10:00 Tuesday morning", now: now)
        guard let res = r.resolution else { return XCTFail("No resolution") }
        guard case .instant(let date, _, _) = res else { return XCTFail("Expected instant") }
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
        guard case .instant(let date, _, _) = res else { return XCTFail("Expected instant") }
        let comp = TestUtil.comps(date)
        XCTAssertEqual(comp.hour, 19) // 7pm
    }
}
