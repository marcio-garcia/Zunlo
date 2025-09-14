
//import XCTest
//@testable import SmartParseKit
//
//final class ResolveScopeTests: XCTestCase {
//    let c = TestUtil.makeComposer()
//    let p = TestUtil.packEN()
//    
//    func testNextWeekFri1100PicksNextFriday() {
//        let now = TestUtil.now(2025,9,11, 9, 0) // Thu
//        let result = c.parse("rebook team meeting for next week Fri 11:00", now: now, pack: p)
//        
//        let comp = TestUtil.comps(result.context.finalDate)
//        
//        XCTAssertFalse(result.context.isRangeQuery)
//        XCTAssertEqual(comp.weekday, 6) // Friday
//        XCTAssertEqual(comp.hour, 11)
//        XCTAssertEqual(comp.day, 19)    // Next week's Friday is Sept 19, 2025
//    }
//
//    func testChangeToNoonToday() {
//        let now = TestUtil.now(2025,9,11, 9, 0)
//        let result = c.parse("change event team standup meeting to noon", now: now, pack: p)
//        
//        let comp = TestUtil.comps(result.context.finalDate)
//        
//        XCTAssertFalse(result.context.isRangeQuery)
//        XCTAssertEqual(comp.day, 11)
//        XCTAssertEqual(comp.hour, 12)
//    }
//}
