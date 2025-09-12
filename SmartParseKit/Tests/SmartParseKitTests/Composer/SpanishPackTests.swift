
import XCTest
@testable import SmartParseKit

final class SpanishPackTests: XCTestCase {
    func testViernesAMediodia() {
        let c = TestUtil.makeES()
        let now = TestUtil.now(2025,9,11, 9, 0)
        let r = c.parse("cambiar reunión al viernes a mediodía", now: now)
        guard let res = r.resolution else { return XCTFail("No resolution") }
        guard case .instant(let date, _, _) = res else { return XCTFail("Expected instant") }
        let comp = TestUtil.comps(date)
        XCTAssertEqual(comp.weekday, 6) // Friday
        XCTAssertEqual(comp.hour, 12)
    }
}
