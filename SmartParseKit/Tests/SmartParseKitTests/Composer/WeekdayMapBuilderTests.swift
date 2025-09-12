
import XCTest
@testable import SmartParseKit

final class WeekdayMapBuilderTests: XCTestCase {
    func testEnglishAliasesExist() {
        let pack = EnglishPack(calendar: Calendar(identifier: .gregorian))
        XCTAssertEqual(pack.weekdayMap["mon"], 2)
        XCTAssertEqual(pack.weekdayMap["monday"], 2)
        XCTAssertEqual(pack.weekdayMap["fri"], 6)
    }

    func testPortugueseAliases() {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "pt_BR")
        let pack = PortugueseBRPack(calendar: cal)
        XCTAssertEqual(pack.weekdayMap["segunda"], 2)
        XCTAssertEqual(pack.weekdayMap["terca"], 3)
        XCTAssertEqual(pack.weekdayMap["quarta"], 4)
    }
}
