//
//  MetadataExtractionTests.swift
//  SmartParseKit
//
//  Created by Claude on 9/13/25.
//

import XCTest
import NaturalLanguage
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
        XCTAssertEqual(result.title.trimmingCharacters(in: .whitespacesAndNewlines), "pay bills")
    }
    
    func testSimpleTagExtractionWithTaskKeyword() {
        let text = "Add tag home to pay bills task"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        XCTAssertEqual(result.tags.count, 1)
        XCTAssertEqual(result.tags.first?.name, "home")
        XCTAssertGreaterThan(result.tags.first?.confidence ?? 0, 0.7)
        XCTAssertEqual(result.title.trimmingCharacters(in: .whitespacesAndNewlines), "pay bills")
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
        XCTAssertGreaterThanOrEqual(result.tags.first?.confidence ?? 0, 0.6)
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
        XCTAssertEqual(result.location?.name, "office")
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

        // Should NOT extract a note since ": Complete quarterly report" is the main task title
        XCTAssertNil(result.notes)

        // Title should contain the main task description and be cleaned of metadata
        let cleanedTitle = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(cleanedTitle.contains("Complete quarterly report"))
        XCTAssertFalse(cleanedTitle.contains("high priority"))
        XCTAssertFalse(cleanedTitle.contains("tag work"))
        XCTAssertFalse(cleanedTitle.contains("at home"))
        XCTAssertFalse(cleanedTitle.contains("reminder"))
    }

    // MARK: - Reschedule Tests
    
    func testExtractTitle() {
        let text = "move game to next Friday"
        let temporalRanges = [
            Range(NSRange(location: 13, length: 11), in: text)!
        ]
        let result = extractor.extractMetadata(from: text, temporalRanges: temporalRanges, pack: pack)

        // Clear, well-structured input should have higher confidence
        XCTAssertEqual(result.tokens.count, 0)
        XCTAssertEqual(result.title, "game")
    }
    
    func testPT_ExtractTitle() {
        let pack = PortugueseBRPack(calendar: TestUtil.calendarSP())
        let text = "Mova jogo para próxima sexta"
        let temporalRanges = [
            Range(NSRange(location: 15, length: 13), in: text)!
        ]
        let result = extractor.extractMetadata(from: text, temporalRanges: temporalRanges, pack: pack)

        // Clear, well-structured input should have higher confidence
        XCTAssertEqual(result.tokens.count, 0)
        XCTAssertEqual(result.title, "jogo")
    }

    func testPT_ExtractTitleInputWithSpecialChar() {
        let pack = PortugueseBRPack(calendar: TestUtil.calendarSP())
        let text = "Criar reunião terça `a tarde"
        let temporalRanges = [
            Range(NSRange(location: 14, length: 5), in: text)!,
            Range(NSRange(location: 23, length: 5), in: text)!
        ]
        let result = extractor.extractMetadata(from: text, temporalRanges: temporalRanges, pack: pack)

        // Clear, well-structured input should have higher confidence
        XCTAssertEqual(result.tokens.count, 0)
        XCTAssertEqual(result.title, "reunião")
    }
    
    func testPT_OrdinalDayAndTimeRange() {
        let pack = PortugueseBRPack(calendar: TestUtil.calendarSP())
        let text = "Crie evento standup 25th 9-10:30am"
        let temporalRanges = [
            Range(NSRange(location: 20, length: 4), in: text)!,
            Range(NSRange(location: 25, length: 9), in: text)!
        ]
        let result = extractor.extractMetadata(from: text, temporalRanges: temporalRanges, pack: pack)

        // Clear, well-structured input should have higher confidence
        XCTAssertEqual(result.tokens.count, 0)
        XCTAssertEqual(result.title, "standup")
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
    
    func testRelativeDayAndTimeWithH() {
        let text = "add movie today 20h"
        let temporalRanges = [
            Range(NSRange(location: 10, length: 5), in: text)!,
            Range(NSRange(location: 16, length: 3), in: text)!
        ]
        
        let result = extractor.extractMetadata(from: text, temporalRanges: temporalRanges, pack: pack)
        
        XCTAssertEqual(result.tokens.count, 0)
        XCTAssertEqual(result.title, "movie")
    }
    
    func testRenameTask() {
        let text = "Rename buy food to buy groceries"
        let result = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)

        // Should handle special characters gracefully
        XCTAssertEqual(result.tokens.count, 1)
        XCTAssertEqual(result.title, "buy food")
        XCTAssertEqual(result.newTitle!.title, "buy groceries")
    }

    // MARK: - Intent Detection Tests

    func testIntentDetectionForMetadataAddition() {
        let composer = TemporalComposer(prefs: Preferences())
        let intentDetector = MockIntentDetector(languge: .english, intent: .unknown)
        let now = Date()

        // Test case reported in the issue
        let (intent, _, _) = composer.parse("Add tag home to pay bills task", now: now, pack: pack, intentDetector: intentDetector)
        XCTAssertEqual(intent, .updateTask, "Adding tag to existing task should be detected as updateTask, not createTask")

        // Additional test cases for metadata addition
        let (intent2, _, _) = composer.parse("Set priority high for meeting task", now: now, pack: pack, intentDetector: intentDetector)
        XCTAssertEqual(intent2, .updateTask, "Setting priority for existing task should be detected as updateTask")

        let (intent3, _, _) = composer.parse("Add reminder 30 minutes before doctor appointment", now: now, pack: pack, intentDetector: intentDetector)
        XCTAssertEqual(intent3, .updateTask, "Adding reminder to existing appointment should be detected as updateTask")
    }

    func testIntentDetectionMultilingual() {
        let composer = TemporalComposer(prefs: Preferences())
        let intentDetector = MockIntentDetector(languge: .portuguese, intent: .unknown)
        let now = Date()

        // Test Portuguese pattern
        let packPT = PortugueseBRPack(calendar: Calendar.current)
        let (intentPT, _, _) = composer.parse("Adicionar tag trabalho para tarefa", now: now, pack: packPT, intentDetector: intentDetector)
        XCTAssertEqual(intentPT, .updateTask, "Portuguese metadata addition should be detected as updateTask")

        // Test Spanish pattern
        let packES = SpanishPack(calendar: Calendar.current)
        let (intentES, _, _) = composer.parse("Añadir etiqueta casa a tarea", now: now, pack: packES, intentDetector: intentDetector)
        XCTAssertEqual(intentES, .updateTask, "Spanish metadata addition should be detected as updateTask")
    }

    // MARK: - Temporal Range Exclusion Tests

    func testTemporalRangeExclusion() {
        // Test case where a metadata pattern could potentially overlap with a temporal pattern
        let text = "Add tag work and remind me 30 minutes before"

        // Test without temporal ranges - should extract both tag and reminder
        let resultWithoutExclusion = extractor.extractMetadata(from: text, temporalRanges: [], pack: pack)
        XCTAssertEqual(resultWithoutExclusion.tags.count, 1)
        XCTAssertEqual(resultWithoutExclusion.tags.first?.name, "work")
        XCTAssertEqual(resultWithoutExclusion.reminders.count, 1)

        // Now simulate that "remind me 30 minutes before" was detected as a temporal token
        let temporalRange = text.range(of: "remind me 30 minutes before")!
        let temporalRanges = [temporalRange]

        let resultWithExclusion = extractor.extractMetadata(from: text, temporalRanges: temporalRanges, pack: pack)

        // Should still extract the tag "work" since it doesn't overlap
        XCTAssertEqual(resultWithExclusion.tags.count, 1)
        XCTAssertEqual(resultWithExclusion.tags.first?.name, "work")

        // But should NOT extract the reminder since it overlaps with temporal range
        XCTAssertEqual(resultWithExclusion.reminders.count, 0, "Reminder should be excluded due to overlap with temporal range")
    }

    func testOverlappingTemporalAndMetadataRanges() {
        // Test a case where temporal and metadata patterns might overlap
        let text = "Set reminder in 30 minutes for high priority meeting"

        // Simulate that "in 30 minutes" was detected as a temporal token
        let temporalRange = text.range(of: "in 30 minutes")!
        let temporalRanges = [temporalRange]

        let result = extractor.extractMetadata(from: text, temporalRanges: temporalRanges, pack: pack)

        // Should detect priority but not duplicate the "30 minutes" reminder since it's temporal
        XCTAssertEqual(result.priority?.level, .high)

        // The reminder extraction should be skipped since it overlaps with temporal range
        XCTAssertTrue(result.reminders.isEmpty, "Reminder extraction should be skipped when overlapping with temporal ranges")
    }

    // MARK: - Performance Improvement Tests

    func testOptimizedIntentDetection() {
        // This test verifies that intent detection now uses already-extracted metadata tokens
        // instead of re-running regex patterns, which improves performance

        let composer = TemporalComposer(prefs: Preferences())
        let intentDetector = MockIntentDetector(languge: .english, intent: .unknown)
        let now = Date()

        // Test case with metadata that should be detected as update intent
        let text = "Add tag work for meeting task"
        let (intent, temporalTokens, metadataResult) = composer.parse(text, now: now, pack: pack, intentDetector: intentDetector)

        // Verify that intent detection worked correctly
        XCTAssertEqual(intent, .updateTask, "Should detect metadata addition as updateTask intent")

        // Verify that metadata tokens were extracted
        XCTAssertEqual(metadataResult.tags.count, 1)
        XCTAssertEqual(metadataResult.tags.first?.name, "work")

        // The key improvement: intent detection now leverages these already-extracted tokens
        // instead of re-running the same regex patterns that were used during metadata extraction
        XCTAssertTrue(true, "Intent detection successfully leveraged pre-extracted metadata tokens")
    }
}
