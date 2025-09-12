
import XCTest
@testable import SmartParseKit

final class IntentTests: XCTestCase {
    func testEnglishIntents() {
        let c = TestUtil.makeEN()
        let r1 = c.parse("schedule client meeting for 10am tomorrow", now: TestUtil.now(2025,9,11))
        XCTAssertEqual(r1.intent, .create)
        let r2 = c.parse("rebook team meeting for next week", now: TestUtil.now(2025,9,11))
        XCTAssertEqual(r2.intent, .reschedule)
        let r3 = c.parse("remove dentist appointment next week", now: TestUtil.now(2025,9,11))
        XCTAssertEqual(r3.intent, .cancel)
        let r4 = c.parse("show agenda for next Thursday morning", now: TestUtil.now(2025,9,11))
        XCTAssertEqual(r4.intent, .view)
        let r5 = c.parse("help me plan my week", now: TestUtil.now(2025,9,11))
        XCTAssertEqual(r5.intent, .plan)
    }

    func testPortugueseIntents() {
        let c = TestUtil.makePT()
        let r = c.parse("reagendar reunião para próxima semana", now: TestUtil.now(2025,9,11))
        XCTAssertEqual(r.intent, .reschedule)
        let r2 = c.parse("planejar minha semana", now: TestUtil.now(2025,9,11))
        XCTAssertEqual(r2.intent, .plan)
    }

    func testSpanishIntents() {
        let c = TestUtil.makeES()
        let r = c.parse("reprogramar reunión para la próxima semana", now: TestUtil.now(2025,9,11))
        XCTAssertEqual(r.intent, .reschedule)
        let r2 = c.parse("mostrar mi agenda para mañana", now: TestUtil.now(2025,9,11))
        XCTAssertEqual(r2.intent, .view)
    }
}
