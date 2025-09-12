
import XCTest
@testable import SmartParseKit

final class PortuguesePackTests: XCTestCase {
    func testSexta16h() {
        let c = TestUtil.makePT()
        let now = TestUtil.now(2025,9,11, 9, 0) // quinta
        let r = c.parse("mudar consulta para esta sexta às 16:00", now: now)
        guard let res = r.resolution else { return XCTFail("No resolution") }
        guard case .instant(let date, _, _) = res else { return XCTFail("Expected instant") }
        let comp = TestUtil.comps(date)
        XCTAssertEqual(comp.weekday, 6) // Friday
        XCTAssertEqual(comp.hour, 16)
        XCTAssertEqual(comp.minute, 0)
    }

    func testFimDeSemanaRangeOnView() {
        let c = TestUtil.makePT()
        let now = TestUtil.now(2025,9,11, 9, 0)
        let r = c.parse("ver agenda para o fim de semana", now: now)
        guard let res = r.resolution else { return XCTFail("No resolution") }
        if case .range(let interval, _, _) = res {
            // Should start on Saturday
            XCTAssertEqual(TestUtil.comps(interval.start).weekday, 7)
        } else {
            XCTFail("Expected range")
        }
    }
}
