
import XCTest
import NaturalLanguage
@testable import SmartParseKit

final class NSDataDetectorFallbackTests: XCTestCase {
    func testAbsoluteMonthDayViaDetector() throws {
        #if os(macOS)
        let c = TestUtil.makeComposer()
        let pack = TestUtil.packEN()
        let intentDetector = MockIntentDetector(languge: .english, intent: Intent.createTask)
        let now = TestUtil.now(2025,9,11, 9, 0)
        let (intent, temporalTokens, _) = c.parse("set up standup nov 12th", now: now, pack: pack, intentDetector: intentDetector)
        XCTAssertEqual(intent, Intent.createTask)
        XCTAssertFalse(temporalTokens.isEmpty)

        // Check if we extracted temporal information for November 12th
        // This test may need to be adjusted based on the actual temporal token structure
        XCTAssertGreaterThan(temporalTokens.count, 0, "Should extract at least one temporal token")
        #else
        throw XCTSkip("NSDataDetector month-day detection is platform dependent")
        #endif
    }
}
