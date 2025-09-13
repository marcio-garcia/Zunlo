
import XCTest
@testable import SmartParseKit

final class SpanishPackTests: XCTestCase {
    let c = TestUtil.makeComposer()
    let p = TestUtil.packES()
    
    func testViernesAMediodia() {
        let now = TestUtil.now(2025,9,11, 9, 0)
        let result = c.parse("cambiar reunión al viernes a mediodía", now: now, pack: p)
        
        let comp = TestUtil.comps(result.context.finalDate)
        
        XCTAssertFalse(result.context.isRangeQuery)
        XCTAssertEqual(comp.weekday, 6) // Friday
        XCTAssertEqual(comp.hour, 12)
    }
}
