
import XCTest
@testable import SmartParseKit

final class NSDataDetectorFallbackTests: XCTestCase {
    func testAbsoluteMonthDayViaDetector() throws {
        #if os(macOS)
        let c = TestUtil.makeEN()
        let now = TestUtil.now(2025,9,11, 9, 0)
        let r = c.parse("set up standup nov 12th", now: now)
        guard let res = r.resolution else { return XCTFail("No resolution") }
        guard case .instant(let date, _, _) = res else { return XCTFail("Expected instant") }
        let comp = TestUtil.comps(date)
        XCTAssertEqual(comp.month, 11)
        XCTAssertEqual(comp.day, 12)
        #else
        throw XCTSkip("NSDataDetector month-day detection is platform dependent")
        #endif
    }
}
