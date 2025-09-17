//
//  TestUtil.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/17/25.
//

import Foundation
import SmartParseKit
@testable import Zunlo

enum TestUtil {
    static func temporalComposerPrefs() -> Preferences {
        var p = Preferences()
        let cal = calendarSP()
        p.calendar = cal
        p.startOfWeek = cal.firstWeekday
        return p
    }

    static func calendarSP() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        cal.firstWeekday = 2 // Monday
        cal.locale = nil
        return cal
    }
    
    static func makeNow() -> Date {
        // 2025-09-11 10:00:00 -03:00 (America/Sao_Paulo)
        var comps = DateComponents()
        comps.year = 2025; comps.month = 9; comps.day = 11
        comps.hour = 10; comps.minute = 0; comps.second = 0
        comps.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    static func components(_ date: Date) -> (y:Int,m:Int,d:Int,h:Int,min:Int) {
        let cal = TestUtil.calendarSP()
        let c = cal.dateComponents([.year,.month,.day,.hour,.minute], from: date)
        return (c.year!, c.month!, c.day!, c.hour!, c.minute!)
    }
}
