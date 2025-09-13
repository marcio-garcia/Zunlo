
import XCTest
@testable import SmartParseKit

final class InlineTimeRangeTests: XCTestCase {
    let c = TestUtil.makeComposer()
    let p = TestUtil.packEN()
    
    func testWeekdayWithTime() {
        let now = TestUtil.now(2025,9,11, 9, 0) // Thu
        let result = c.parse("schedule coffee with Ana for 10:00 Tuesday morning", now: now, pack: p)
        let comp = TestUtil.comps(result.context.finalDate)
        
        XCTAssertFalse(result.context.isRangeQuery)
        XCTAssertEqual(comp.weekday, 3) // Tuesday
        XCTAssertEqual(comp.hour, 10)
        XCTAssertEqual(comp.minute, 0)
    }

    func testPivotChoosesRightmostAfterAt() {
        let now = TestUtil.now(2025,9,11, 9, 0)
        
        let result = c.parse("dinner with parents tonight 8pm at 7pm", now: now, pack: p)
        
        let comp = TestUtil.comps(result.context.finalDate)
        
        XCTAssertFalse(result.context.isRangeQuery)
        XCTAssertEqual(comp.hour, 19) // 7pm
    }
    
    func testWeekdayWithTimeRange() {
        let now = TestUtil.now(2025,9,11, 9, 0)
        
        let result = c.parse("team meeting Wed 8am to 9am", now: now, pack: p)
        
        let comp = TestUtil.comps(result.context.finalDate)
        
        XCTAssertFalse(result.context.isRangeQuery)
        XCTAssertEqual(comp.year, 2025); XCTAssertEqual(comp.month, 9); XCTAssertEqual(comp.day, 17)
        XCTAssertEqual(comp.hour, 8); XCTAssertEqual(comp.minute, 0)
        XCTAssertEqual(result.context.finalDateDuration, 3600)
    }
}
