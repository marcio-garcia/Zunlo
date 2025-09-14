//
//  MetadataExtractionTests.swift
//  SmartParseKit
//
//  Created by Claude on 9/13/25.
//

import XCTest
@testable import SmartParseKit

final class MetadataExtractionTests: XCTestCase {
    private var pack: EnglishPack!
    private var extractor: MetadataExtractor!

    override func setUp() {
        super.setUp()
        pack = EnglishPack(calendar: Calendar.current)
        extractor = MetadataExtractor()
    }

    // MARK: - Tag Extraction Tests

    func testSimpleTagExtraction() {
        let text = "Add tag home to pay bills tomorrow"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        XCTAssertEqual(result.tags.count, 1)
        XCTAssertEqual(result.tags.first?.name, "home")
        XCTAssertGreaterThan(result.tags.first?.confidence ?? 0, 0.7)
        XCTAssertEqual(result.title.trimmingCharacters(in: .whitespacesAndNewlines), "pay bills tomorrow")
    }

    func testMultipleTagsExtraction() {
        let text = "Create task with tags work,urgent for the presentation"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        XCTAssertEqual(result.tags.count, 2)
        let tagNames = result.tags.map { $0.name }.sorted()
        XCTAssertEqual(tagNames, ["urgent", "work"])
    }

    func testTaggedAsPattern() {
        let text = "Schedule meeting tagged as important for next week"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        XCTAssertEqual(result.tags.count, 1)
        XCTAssertEqual(result.tags.first?.name, "important")
        XCTAssertGreaterThan(result.tags.first?.confidence ?? 0, 0.6)
    }

    // MARK: - Priority Extraction Tests

    func testPriorityHighExtraction() {
        let text = "Create high priority task for client meeting"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        XCTAssertNotNil(result.priority)
        XCTAssertEqual(result.priority?.level, .high)
        XCTAssertGreaterThan(result.priority?.confidence ?? 0, 0.7)
    }

    func testUrgentPriorityExtraction() {
        let text = "Add urgent task to fix server issue"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        XCTAssertNotNil(result.priority)
        XCTAssertEqual(result.priority?.level, .urgent)
        XCTAssertGreaterThan(result.priority?.confidence ?? 0, 0.8)
    }

    // MARK: - Reminder Extraction Tests

    func testReminderTimeOffsetExtraction() {
        let text = "Remind me 30 minutes before the dentist appointment"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        XCTAssertEqual(result.reminders.count, 1)
        if case .timeOffset(let interval) = result.reminders.first?.trigger {
            XCTAssertEqual(interval, 30 * 60) // 30 minutes in seconds
        } else {
            XCTFail("Expected timeOffset reminder trigger")
        }
    }

    func testSetReminderPattern() {
        let text = "Set reminder for 2 hours before the flight"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        XCTAssertEqual(result.reminders.count, 1)
        if case .timeOffset(let interval) = result.reminders.first?.trigger {
            XCTAssertEqual(interval, 2 * 3600) // 2 hours in seconds
        } else {
            XCTFail("Expected timeOffset reminder trigger")
        }
    }

    // MARK: - Location Extraction Tests

    func testLocationAtPattern() {
        let text = "Schedule meeting at the office tomorrow"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        XCTAssertNotNil(result.location)
        XCTAssertEqual(result.location?.name, "the office")
        XCTAssertGreaterThan(result.location?.confidence ?? 0, 0.5)
    }

    func testLocationInPattern() {
        let text = "Book dinner in downtown restaurant"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        XCTAssertNotNil(result.location)
        XCTAssertEqual(result.location?.name, "downtown restaurant")
    }

    // MARK: - Notes Extraction Tests

    func testNotesColonPattern() {
        let text = "Add task note: Remember to bring documents for the meeting"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        XCTAssertNotNil(result.notes)
        XCTAssertEqual(result.notes?.content, "Remember to bring documents for the meeting")
        XCTAssertGreaterThan(result.notes?.confidence ?? 0, 0.7)
    }

    // MARK: - Complex Integration Tests

    func testComplexMetadataExtraction() {
        let text = "Add high priority tag work task at home with reminder 1 hour before: Complete quarterly report"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        // Should extract tag, priority, location, reminder, and notes
        XCTAssertEqual(result.tags.count, 1)
        XCTAssertEqual(result.tags.first?.name, "work")

        XCTAssertNotNil(result.priority)
        XCTAssertEqual(result.priority?.level, .high)

        XCTAssertNotNil(result.location)
        XCTAssertEqual(result.location?.name, "home")

        XCTAssertEqual(result.reminders.count, 1)
        if case .timeOffset(let interval) = result.reminders.first?.trigger {
            XCTAssertEqual(interval, 3600) // 1 hour
        } else {
            XCTFail("Expected timeOffset reminder trigger")
        }

        XCTAssertNotNil(result.notes)
        XCTAssertEqual(result.notes?.content, "Complete quarterly report")

        // Title should be cleaned of metadata
        let cleanedTitle = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(cleanedTitle.contains("high priority"))
        XCTAssertFalse(cleanedTitle.contains("tag work"))
        XCTAssertFalse(cleanedTitle.contains("at home"))
        XCTAssertFalse(cleanedTitle.contains("reminder"))
    }

    // MARK: - Confidence Tests

    func testLowConfidenceForAmbiguousInput() {
        let text = "a"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        // Very short input should have low confidence
        XCTAssertLessThan(result.confidence, 0.3)
    }

    func testHighConfidenceForClearInput() {
        let text = "Add tag work to schedule team meeting at conference room"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        // Clear, well-structured input should have higher confidence
        XCTAssertGreaterThan(result.confidence, 0.6)
        XCTAssertEqual(result.tags.count, 1)
        XCTAssertEqual(result.tags.first?.name, "work")
        XCTAssertNotNil(result.location)
    }

    // MARK: - Conflict Detection Tests

    func testPriorityConflictDetection() {
        let text = "Add high priority urgent task"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        // Should detect multiple priority indicators as a conflict
        XCTAssertGreaterThan(result.conflicts.count, 0)
        XCTAssertTrue(result.conflicts.contains { $0.description.contains("priority") })
    }

    // MARK: - Edge Cases

    func testEmptyInput() {
        let text = ""
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        XCTAssertEqual(result.tokens.count, 0)
        XCTAssertEqual(result.title, "")
        XCTAssertEqual(result.confidence, 0.0)
    }

    func testInputWithOnlyWhitespace() {
        let text = "   \t  \n  "
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        XCTAssertEqual(result.tokens.count, 0)
        XCTAssertEqual(result.title, "")
    }

    func testInputWithSpecialCharacters() {
        let text = "Add tag @work to #meeting task!"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        // Should handle special characters gracefully
        XCTAssertGreaterThan(result.tokens.count, 0)
        XCTAssertFalse(result.title.isEmpty)
    }
}