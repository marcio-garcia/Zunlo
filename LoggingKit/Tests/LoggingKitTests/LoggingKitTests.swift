import XCTest
@testable import LoggingKit

final class LoggingKitTests: XCTestCase {

    final class CaptureDestination: Logger.Destination {
        var minLevel: Logger.Level = .trace
        var predicate: (@Sendable (Logger.Entry) -> Bool)?
        var entries: [Logger.Entry] = []
        func write(_ entry: Logger.Entry) { entries.append(entry) }
    }

    func testCallSiteMetadata() {
        let cap = CaptureDestination()
        Logger.shared.replaceDestinations(with: [cap])

        // Act: log from here
        let expectedFile = (#fileID as String).split(separator: "/").last!
        let expectedFunction = #function
        let expectedLine = #line + 1
        Logger.shared.debug("hello tests")
        // Assert
        guard let e = cap.entries.last else { return XCTFail("No entry captured") }
        XCTAssertTrue(e.metadata.fileID.hasSuffix(String(expectedFile)))
        XCTAssertEqual(e.metadata.function, expectedFunction)
        XCTAssertGreaterThanOrEqual(Int(e.metadata.line), expectedLine)
        XCTAssertEqual(e.message, "hello tests")
    }

    func testFiltering() {
        let cap = CaptureDestination()
        cap.minLevel = .info
        Logger.shared.replaceDestinations(with: [cap])

        Logger.shared.debug("drop me")
        Logger.shared.info("keep me")

        XCTAssertEqual(cap.entries.count, 2)
        XCTAssertEqual(cap.entries.first?.level, .debug)
    }
}
