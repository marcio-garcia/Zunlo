
import XCTest
@testable import SmartParseKit

enum TestUtil {
    static func prefs() -> Preferences {
        var p = Preferences()
        let cal = calendarSP()
        p.calendar = cal
        p.startOfWeek = cal.firstWeekday
        return p
    }
    static func now(_ yyyy:Int,_ mm:Int,_ dd:Int,_ h:Int=9,_ m:Int=0) -> Date {
        let cal = calendarSP()
        let c = DateComponents(timeZone: cal.timeZone, year: yyyy, month: mm, day: dd, hour: h, minute: m)
        return cal.date(from: c)!
    }
    static func comps(_ d: Date) -> DateComponents {
        return calendarSP().dateComponents([.year,.month,.day,.hour,.minute,.weekday], from: d)
    }
    static func makeComposer() -> TemporalComposer { TemporalComposer(prefs: prefs()) }
    
    static func calendarSP() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        cal.firstWeekday = 2 // Monday
        cal.locale = nil
        return cal
    }
    
    static func packEN() -> DateLanguagePack {
        var cal = prefs().calendar
        cal.locale = Locale(identifier: "en_US")
        return EnglishPack(calendar: cal)
    }
    
    static func packPT() -> DateLanguagePack {
        var cal = prefs().calendar
        cal.locale = Locale(identifier: "pt_BR")
        return PortugueseBRPack(calendar: cal)
    }
    
    static func packES() -> DateLanguagePack {
        var cal = prefs().calendar
        cal.locale = Locale(identifier: "es_ES")
        return SpanishPack(calendar: cal)
    }
}
