
import XCTest
@testable import SmartParseKit

enum TestUtil {
    static let calendar = Calendar(identifier: .gregorian)
    static let tz = TimeZone(identifier: "America/Sao_Paulo")!
    static func prefs() -> Preferences {
        var p = Preferences()
        p.calendar = calendar
        p.calendar.timeZone = tz
        p.startOfWeek = 2 // Monday
        return p
    }
    static func now(_ yyyy:Int,_ mm:Int,_ dd:Int,_ h:Int=9,_ m:Int=0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = DateComponents(timeZone: tz, year: yyyy, month: mm, day: dd, hour: h, minute: m)
        return cal.date(from: c)!
    }
    static func comps(_ d: Date) -> DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.dateComponents([.year,.month,.day,.hour,.minute,.weekday], from: d)
    }
    static func makeComposer() -> TemporalComposer { TemporalComposer(prefs: prefs()) }
    
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
