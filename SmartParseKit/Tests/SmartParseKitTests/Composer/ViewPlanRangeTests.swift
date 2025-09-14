
//import XCTest
//@testable import SmartParseKit
//
//final class ViewPlanRangeTests: XCTestCase {
//    let c = TestUtil.makeComposer()
//    let p = TestUtil.packEN()
//    
//    func testAgendaNextThursdayMorningIsRange() {
//        let now = TestUtil.now(2025,9,11, 9, 0) // Thu Sep 11, 2025
//        let result = c.parse("show agenda for next Thursday morning", now: now, pack: p)
//        let startComp = TestUtil.comps(result.context.dateRange!.start)
//        let endComp = TestUtil.comps(result.context.dateRange!.end)
//        
//        XCTAssertTrue(result.context.isRangeQuery)
//        XCTAssertEqual(startComp.year, 2025); XCTAssertEqual(startComp.month, 9); XCTAssertEqual(startComp.day, 18)
//        XCTAssertEqual(startComp.hour, 6); XCTAssertEqual(startComp.minute, 0)
//        XCTAssertEqual(endComp.year, 2025); XCTAssertEqual(endComp.month, 9); XCTAssertEqual(endComp.day, 18)
//        XCTAssertEqual(endComp.hour, 11); XCTAssertEqual(endComp.minute, 59)
//    }
//
//    func testBareWeekPlansThisWeekRange() {
//        let now = TestUtil.now(2025,9,11, 9, 0)
//        let result = c.parse("show agenda for this week", now: now, pack: p)
//        let startComp = TestUtil.comps(result.context.dateRange!.start)
//        let endComp = TestUtil.comps(result.context.dateRange!.end)
//        
//        let interval = try? secondsBetween(startComp, endComp)
//        
//        XCTAssertTrue(result.context.isRangeQuery)
//        // Start of week is Monday (prefs.startOfWeek = 2)
//        XCTAssertEqual(startComp.weekday, 2)
//        XCTAssertEqual(endComp.weekday, 1)
//        XCTAssertEqual(startComp.year, 2025); XCTAssertEqual(startComp.month, 9); XCTAssertEqual(startComp.day, 8)
//        XCTAssertEqual(startComp.hour, 0); XCTAssertEqual(startComp.minute, 0)
//        XCTAssertEqual(endComp.year, 2025); XCTAssertEqual(endComp.month, 9); XCTAssertEqual(endComp.day, 14)
//        XCTAssertEqual(endComp.hour, 23); XCTAssertEqual(endComp.minute, 59)
//        XCTAssertEqual(interval!, 7*24*3600, accuracy: 60)
//    }
//}
