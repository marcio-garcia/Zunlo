
//import XCTest
//@testable import SmartParseKit
//
//final class IntentTests: XCTestCase {
//    let c = TestUtil.makeComposer()
//    
//    func testEnglishIntents() {
//        let p = TestUtil.packEN()
//        let r1 = c.parse("schedule client meeting for 10am tomorrow", now: TestUtil.now(2025,9,11), pack: p)
//        XCTAssertEqual(r1.intent, .create)
//        let r2 = c.parse("rebook team meeting for next week", now: TestUtil.now(2025,9,11), pack: p)
//        XCTAssertEqual(r2.intent, .reschedule)
//        let r3 = c.parse("remove dentist appointment next week", now: TestUtil.now(2025,9,11), pack: p)
//        XCTAssertEqual(r3.intent, .cancel)
//        let r4 = c.parse("show agenda for next Thursday morning", now: TestUtil.now(2025,9,11), pack: p)
//        XCTAssertEqual(r4.intent, .view)
//        let r5 = c.parse("help me plan my week", now: TestUtil.now(2025,9,11), pack: p)
//        XCTAssertEqual(r5.intent, .plan)
//        let r6 = c.parse("create task to buy cat food", now: TestUtil.now(2025,9,11), pack: p)
//        XCTAssertEqual(r6.intent, .create)
//    }
//
//    func testPortugueseIntents() {
//        let p = TestUtil.packPT()
//        let r = c.parse("reagendar reunião para próxima semana", now: TestUtil.now(2025,9,11), pack: p)
//        XCTAssertEqual(r.intent, .reschedule)
//        let r2 = c.parse("planejar minha semana", now: TestUtil.now(2025,9,11), pack: p)
//        XCTAssertEqual(r2.intent, .plan)
//    }
//
//    func testSpanishIntents() {
//        let p = TestUtil.packES()
//        let r = c.parse("reprogramar reunión para la próxima semana", now: TestUtil.now(2025,9,11), pack: p)
//        XCTAssertEqual(r.intent, .reschedule)
//        let r2 = c.parse("mostrar mi agenda para mañana", now: TestUtil.now(2025,9,11), pack: p)
//        XCTAssertEqual(r2.intent, .view)
//    }
//}
