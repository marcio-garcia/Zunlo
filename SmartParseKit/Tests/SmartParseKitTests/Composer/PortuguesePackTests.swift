
//import XCTest
//@testable import SmartParseKit
//
//final class PortuguesePackTests: XCTestCase {
//    let c = TestUtil.makeComposer()
//    let p = TestUtil.packPT()
//    
//    func testSexta16h() {
//        let now = TestUtil.now(2025,9,11, 9, 0) // quinta
//        let result = c.parse("mudar consulta para esta sexta às 16:00", now: now, pack: p)
//        let comp = TestUtil.comps(result.context.finalDate)
//        
//        XCTAssertFalse(result.context.isRangeQuery)
//        XCTAssertEqual(comp.weekday, 6) // Friday
//        XCTAssertEqual(comp.hour, 16)
//        XCTAssertEqual(comp.minute, 0)
//    }
//
//    func testFimDeSemanaRangeOnView() {
//        let now = TestUtil.now(2025,9,11, 9, 0)
//        let result = c.parse("ver agenda para o fim de semana", now: now, pack: p)
//        let startComp = TestUtil.comps(result.context.dateRange!.start)
//        let endComp = TestUtil.comps(result.context.dateRange!.end)
//
//        XCTAssertTrue(result.context.isRangeQuery)
//        XCTAssertEqual(startComp.weekday, 7) // Should start on Saturday
//        XCTAssertEqual(startComp.year, 2025); XCTAssertEqual(startComp.month, 9); XCTAssertEqual(startComp.day, 13);
//        XCTAssertEqual(startComp.hour, 0); XCTAssertEqual(startComp.minute, 0);
//        XCTAssertEqual(endComp.weekday, 1) // Sunday
//        XCTAssertEqual(endComp.year, 2025); XCTAssertEqual(endComp.month, 9); XCTAssertEqual(endComp.day, 14);
//        XCTAssertEqual(endComp.hour, 23); XCTAssertEqual(endComp.minute, 59);
//    }
//}
