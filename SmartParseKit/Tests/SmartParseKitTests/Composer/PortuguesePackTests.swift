
import XCTest
@testable import SmartParseKit

final class PortuguesePackTests: XCTestCase {
    func testSexta16h() {
        let c = TestUtil.makePT()
        let now = TestUtil.now(2025,9,11, 9, 0) // quinta
        let r = c.parse("mudar consulta para esta sexta às 16:00", now: now)
        guard let res = r.resolution else { return XCTFail("No resolution") }
        guard case .instant(let date, _, _, _) = res else { return XCTFail("Expected instant") }
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
            let startComp = TestUtil.comps(interval.start)
            let endComp = TestUtil.comps(interval.end)
            
            XCTAssertEqual(startComp.weekday, 7) // Should start on Saturday
            XCTAssertEqual(startComp.year, 2025); XCTAssertEqual(startComp.month, 9); XCTAssertEqual(startComp.day, 13);
            XCTAssertEqual(startComp.hour, 0); XCTAssertEqual(startComp.minute, 0);
            XCTAssertEqual(endComp.weekday, 1) // Sunday
            XCTAssertEqual(endComp.year, 2025); XCTAssertEqual(endComp.month, 9); XCTAssertEqual(endComp.day, 14);
            XCTAssertEqual(endComp.hour, 23); XCTAssertEqual(endComp.minute, 59);
        } else {
            XCTFail("Expected range")
        }
    }
}
