
import XCTest
@testable import SmartParseKit

enum TestUtil {
    static let tz = TimeZone(identifier: "America/Sao_Paulo")!
    static func prefs() -> Preferences {
        var p = Preferences()
        p.timeZone = tz
        p.startOfWeek = 2 // Monday
        return p
    }
    static func now(_ yyyy:Int,_ mm:Int,_ dd:Int,_ h:Int=9,_ m:Int=0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        var c = DateComponents(timeZone: tz, year: yyyy, month: mm, day: dd, hour: h, minute: m)
        return cal.date(from: c)!
    }
    static func comps(_ d: Date) -> DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.dateComponents([.year,.month,.day,.hour,.minute,.weekday], from: d)
    }
    static func makeEN() -> TemporalComposer { TemporalComposer(pack: EnglishPack(calendar: Calendar(identifier: .gregorian)), prefs: prefs()) }
    static func makePT() -> TemporalComposer {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "pt_BR")
        return TemporalComposer(pack: PortugueseBRPack(calendar: cal), prefs: prefs())
    }
    static func makeES() -> TemporalComposer {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "es_ES")
        return TemporalComposer(pack: SpanishPack(calendar: cal), prefs: prefs())
    }
}
