//
//  FakeDateDetector.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/8/25.
//

import Foundation
@testable import SmartParseKit

// Small helpers for tests
private func spCalendar() -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.locale = Locale(identifier: "pt_BR")
    cal.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    return cal
}
private func testDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    let cal = spCalendar()
    var comps = DateComponents()
    comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
    return cal.date(from: comps)!
}
private func nsRange(of needle: String, in hay: String) -> NSRange? {
    guard let r = hay.range(of: needle) else { return nil }
    return NSRange(r, in: hay)
}

// MARK: - Fake detector
final class FakeDateDetector: DateDetecting {

    func enumerateMatches(in text: String, range: NSRange, _ body: (NSTextCheckingResult) -> Void) {
        // We match the entire input string (exact equality) to keep tests deterministic.
        switch text {

        // 1) "Vamos nos ver este domingo às 15:00."
        case "Vamos nos ver este domingo às 15:00.":
            if let r = nsRange(of: "este domingo às 15:00", in: text) {
                let d = testDate(2025, 9, 7, 15, 0) // upcoming Sunday from 2025-09-03
                body(NSTextCheckingResult.dateCheckingResult(range: r, date: d))
            }

        // 2) "A oficina é no próximo domingo às 10:00."
        case "A oficina é no próximo domingo às 10:00.":
            if let r = nsRange(of: "próximo domingo às 10:00", in: text) {
                let d = testDate(2025, 9, 7, 10, 0)
                body(NSTextCheckingResult.dateCheckingResult(range: r, date: d))
            }

        // 3) "Vamos marcar para domingo que vem às 09:30."
        case "Vamos marcar para domingo que vem às 09:30.":
            if let r = nsRange(of: "domingo que vem às 09:30", in: text) {
                let d = testDate(2025, 9, 7, 9, 30)
                body(NSTextCheckingResult.dateCheckingResult(range: r, date: d))
            }

        // 4) "Reunião no próximo domingo às 10:00."
        //    (Your policy may later push this to Sep 14 in overrides; we emit Sep 7 so policy can act.)
        case "Reunião no próximo domingo às 10:00.":
            if let r = nsRange(of: "próximo domingo às 10:00", in: text) {
                let d = testDate(2025, 9, 7, 10, 0)
                body(NSTextCheckingResult.dateCheckingResult(range: r, date: d))
            }

        // 5) "almoço este domingo às 12:00"
        //    In your test you change base to the actual Sunday; we still produce Sep 7 @ 12:00.
        case "almoço este domingo às 12:00":
            if let r = nsRange(of: "este domingo às 12:00", in: text) {
                let d = testDate(2025, 9, 7, 12, 0)
                body(NSTextCheckingResult.dateCheckingResult(range: r, date: d))
            }

        // 6) "Evento 28/09/2025 às 18:45."
        case "Evento 28/09/2025 às 18:45.":
            if let r = nsRange(of: "28/09/2025 às 18:45", in: text) {
                let d = testDate(2025, 9, 28, 18, 45)
                body(NSTextCheckingResult.dateCheckingResult(range: r, date: d))
            }

        // 7) "almoço este domingo às 12:00; oficina no próximo domingo às 10:00; encontro domingo que vem 19h"
        //    Emit multiple hits (one per date-like span)
        case "almoço este domingo às 12:00; oficina no próximo domingo às 10:00; encontro domingo que vem 19h":
            if let r1 = nsRange(of: "este domingo às 12:00", in: text) {
                body(NSTextCheckingResult.dateCheckingResult(range: r1, date: testDate(2025, 9, 7, 12, 0)))
            }
            if let r2 = nsRange(of: "próximo domingo às 10:00", in: text) {
                body(NSTextCheckingResult.dateCheckingResult(range: r2, date: testDate(2025, 9, 7, 10, 0)))
            }
            if let r3 = nsRange(of: "domingo que vem 19h", in: text) {
                body(NSTextCheckingResult.dateCheckingResult(range: r3, date: testDate(2025, 9, 7, 19, 0)))
            }

        // 8) "Create event meeting wed 9-10" → Apple typically fails; return no hits (synthetic takes over)
        case "Create event meeting wed 9-10":
            break

        // 9) "reunião qua 10h-12h" → no hits (synthetic)
        case "reunião qua 10h-12h":
            break

        // 10) "standup fri 9"
        //     Apple sometimes treats “9” as day-of-month. We simulate a day=9 hit (no time).
        case "standup fri 9":
            if let r = nsRange(of: "fri 9", in: text) {
                let d = testDate(2025, 9, 9, 12, 0) // noon placeholder (Apple often sets some default time)
                body(NSTextCheckingResult.dateCheckingResult(range: r, date: d))
            }

        // 11) "fri 9am-10" → no hits (synthetic)
        case "fri 9am-10":
            break

        // 12) "sex 11-1" → no hits (synthetic)
        case "sex 11-1":
            break

        // 13) "qua às 10h-11h" → no hits (synthetic)
        case "qua às 10h-11h":
            break

        // 14) "quarta das 9 às 10" → no hits (synthetic)
        case "quarta das 9 às 10":
            break

        // 15) "das 14 às 16" → no hits (synthetic)
        case "das 14 às 16":
            break

        // 16) "de 10hs a 12hrs" → no hits (synthetic)
        case "de 10hs a 12hrs":
            break

        // 17) "wed from 9 to 10" → no hits (synthetic)
        case "wed from 9 to 10":
            break

        // 18) "from 9:30 to 10:15" → no hits (synthetic)
        case "from 9:30 to 10:15":
            break

        // 19) "from 20 to 21" → no hits (synthetic)
        case "from 20 to 21":
            break

        // Default: emit nothing
        default:
            break
        }
    }
}
