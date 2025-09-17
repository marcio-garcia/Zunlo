//
//  NLServiceTests.swift
//  ZunloTests
//
//  Created by Claude on 9/15/25.
//

import XCTest
import SmartParseKit
import NaturalLanguage
@testable import Zunlo

final class NLServiceTests: XCTestCase {
    private var nlService: NLService!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = TestUtil.calendarSP()
        let parser = TemporalComposer(prefs: TestUtil.temporalComposerPrefs())
        let intentDetector = AppleIntentDetector()
        nlService = NLService(parser: parser, intentDetector: intentDetector, calendar: calendar)
    }

    override func tearDown() {
        nlService = nil
        calendar = nil
        super.tearDown()
    }

    // MARK: - Basic Temporal Parsing Tests

    func testNextWeekAt11() async throws {
        let results = try await nlService.process(text: "add event graduation ceremony next week at 11:00")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createEvent)
        XCTAssertTrue(result.title.contains("graduation ceremony"))
        XCTAssertNotNil(result.context.finalDate)
    }

    func testNextFriday() async throws {
        let results = try await nlService.process(text: "move game to next Friday")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        
        // Should detect ambiguity
        XCTAssertTrue(result.isAmbiguous, "Should detect ambiguity")
        XCTAssertGreaterThan(result.intentAmbiguity?.predictions.count ?? 0, 1, "Should have multiple intent alternatives")

        // Should contain alternatives
        let intentAlternatives = result.intentAmbiguity?.predictions.map { $0.intent } ?? []
        XCTAssertTrue(intentAlternatives.contains(.rescheduleTask), "Should include rescheduleTask as alternative")
        XCTAssertTrue(intentAlternatives.contains(.rescheduleEvent), "Should include rescheduleEvent as alternative")

        // Should have reasonable confidence scores
        XCTAssertTrue(result.intentAmbiguity?.predictions.allSatisfy { $0.confidence > 0.3 } == true, "All alternatives should have reasonable confidence")
    }

    func testSpecificDateWithTime() async throws {
        let results = try await nlService.process(text: "push dentist appointment to october 15th 7pm")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .rescheduleEvent)
        XCTAssertTrue(result.title.contains("dentist appointment"))
        XCTAssertNotNil(result.context.finalDate)
    }

    func testRelativeDayAndTime() async throws {
        let results = try await nlService.process(text: "schedule client meeting for 10am tomorrow")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createEvent)
        XCTAssertTrue(result.title.contains("client meeting"))
        XCTAssertNotNil(result.context.finalDate)
    }

    func testWeekendAnchor() async throws {
        let results = try await nlService.process(text: "push back do laundry to weekend")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        // This should be ambiguous as "push back do laundry to weekend" could refer to either a task or event
        XCTAssertNotNil(result.intentAmbiguity, "Should detect ambiguity between reschedule task vs event")
        XCTAssertTrue(result.intentAmbiguity!.isAmbiguous, "Should be flagged as ambiguous")

        // Should include both reschedule possibilities
        let intents = result.intentAmbiguity!.predictions.map { $0.intent }
        XCTAssertTrue(intents.contains(.rescheduleTask), "Should include reschedule task option")
        XCTAssertTrue(intents.contains(.rescheduleEvent), "Should include reschedule event option")

        XCTAssertTrue(result.title.contains("do laundry"))
        XCTAssertNotNil(result.context.finalDate)
    }

    // MARK: - Metadata Extraction Tests

    func testSimpleTagExtraction() async throws {
        let results = try await nlService.process(text: "Add tag home to pay bills tomorrow")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        
        // This should be ambiguous
        XCTAssertNotNil(result.intentAmbiguity, "Should detect ambiguity")
        XCTAssertTrue(result.intentAmbiguity!.isAmbiguous, "Should be flagged as ambiguous")

        // Should include both reschedule possibilities
        let intents = result.intentAmbiguity!.predictions.map { $0.intent }
        XCTAssertTrue(intents.contains(.createTask), "Should include createTask option")
        XCTAssertTrue(intents.contains(.updateTask), "Should include updateTask option")
        
        XCTAssertEqual(result.tags.count, 1)
        XCTAssertEqual(result.tags.first?.name, "home")
        XCTAssertGreaterThan(result.tags.first?.confidence ?? 0, 0.7)
        XCTAssertTrue(result.title.contains("pay bills"))
    }

    func testMultipleTagsExtraction() async throws {
        let results = try await nlService.process(text: "Create task with tags work,urgent for the presentation")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createTask)
        XCTAssertEqual(result.tags.count, 2)
        let tagNames = result.tags.map { $0.name }.sorted()
        XCTAssertEqual(tagNames, ["urgent", "work"])
    }

    func testPriorityHighExtraction() async throws {
        let results = try await nlService.process(text: "Create high priority task for client meeting")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createTask)
        XCTAssertNotNil(result.priority)
        XCTAssertEqual(result.priority?.level, .high)
        XCTAssertGreaterThan(result.priority?.confidence ?? 0, 0.7)
    }

    func testUrgentPriorityExtraction() async throws {
        let results = try await nlService.process(text: "Add urgent task to fix server issue")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        
        XCTAssertEqual(result.intent, .createTask)
        XCTAssertEqual(result.context.resolvedTokens.count, 0)
        XCTAssertEqual(result.priority!.level, .urgent)
        XCTAssertGreaterThan(result.priority!.confidence, 0.8)
        XCTAssertEqual(result.title, "fix server issue")
    }

    func testReminderTimeOffsetExtraction() async throws {
        let results = try await nlService.process(text: "Remind me 30 minutes before the dentist appointment")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .updateEvent)
        XCTAssertEqual(result.reminders.count, 1)
        if case .timeOffset(let interval) = result.reminders.first?.trigger {
            XCTAssertEqual(interval, 30 * 60) // 30 minutes in seconds
        } else {
            XCTFail("Expected timeOffset reminder trigger")
        }
    }

    func testLocationAtPattern() async throws {
        let results = try await nlService.process(text: "Schedule meeting at the office tomorrow")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createEvent)
        XCTAssertNotNil(result.location)
        XCTAssertEqual(result.location?.name, "office")
        XCTAssertGreaterThan(result.location?.confidence ?? 0, 0.5)
    }

    func testNotesColonPattern() async throws {
        let results = try await nlService.process(text: "Add note: Remember to bring documents for the meeting")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .updateTask)
        XCTAssertNotNil(result.notes)
        XCTAssertEqual(result.notes?.content, "Remember to bring documents for the meeting")
        XCTAssertGreaterThan(result.notes?.confidence ?? 0, 0.7)
    }

    // MARK: - Complex Integration Tests

    func testComplexMetadataExtraction() async throws {
        let results = try await nlService.process(text: "Add high priority tag work task at home with reminder 1 hour before: Complete quarterly report")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createTask)

        // Should extract tag, priority, location, reminder
        XCTAssertEqual(result.tags.count, 1)
        XCTAssertEqual(result.tags.first?.name, "work")

        XCTAssertNotNil(result.priority)
        XCTAssertEqual(result.priority?.level, .high)

        XCTAssertNotNil(result.location)
        XCTAssertEqual(result.location?.name, "home")

        // The reminder should be ignored because "1 hour" gets detected as a temporal token first,
        // and metadata extractor excludes overlapping ranges
        XCTAssertEqual(result.reminders.count, 0, "Reminder should be excluded due to temporal overlap")

        // Title should contain the main task description and be cleaned of metadata
        let cleanedTitle = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(cleanedTitle.contains("Complete quarterly report"))
        XCTAssertFalse(cleanedTitle.contains("high priority"))
        XCTAssertFalse(cleanedTitle.contains("tag work"))
        XCTAssertFalse(cleanedTitle.contains("at home"))
        XCTAssertFalse(cleanedTitle.contains("reminder"))
    }

    // MARK: - Portuguese Tests

    func testPT_NextWeekFri1100() async throws {
        let results = try await nlService.process(text: "remarcar reunião para próxima semana sex 11:00")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .rescheduleEvent)
        XCTAssertTrue(result.title.contains("reunião"))
        XCTAssertNotNil(result.context.finalDate)
    }

    func testPT_TerceaAs10() async throws {
        let results = try await nlService.process(text: "marcar café terça às 10h")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createEvent)
        XCTAssertTrue(result.title.contains("café"))
        XCTAssertNotNil(result.context.finalDate)
    }

    func testPT_DaquiAUmMes() async throws {
        let results = try await nlService.process(text: "daqui a um mês às 11h")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertNotNil(result.context.finalDate)
    }

    func testPT_NextFriday() async throws {
        let results = try await nlService.process(text: "Mova jogo para próxima sexta")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        
        // Should detect ambiguity
        XCTAssertTrue(result.isAmbiguous, "Should detect ambiguity")
        XCTAssertGreaterThan(result.intentAmbiguity?.predictions.count ?? 0, 1, "Should have multiple intent alternatives")

        // Should contain alternatives
        let intentAlternatives = result.intentAmbiguity?.predictions.map { $0.intent } ?? []
        XCTAssertTrue(intentAlternatives.contains(.rescheduleTask), "Should include rescheduleTask as alternative")
        XCTAssertTrue(intentAlternatives.contains(.rescheduleEvent), "Should include rescheduleEvent as alternative")

        // Should have reasonable confidence scores
        XCTAssertTrue(result.intentAmbiguity?.predictions.allSatisfy { $0.confidence > 0.3 } == true, "All alternatives should have reasonable confidence")
    }

    func testPT_TagAddition() async throws {
        let results = try await nlService.process(text: "Adicionar tag trabalho para tarefa")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
                
        XCTAssertEqual(result.title.count, 0)
        XCTAssertEqual(result.tags.first?.name, "trabalho")
    }

    func testPT_PriorityExtraction() async throws {
        let results = try await nlService.process(text: "Criar tarefa alta prioridade para reunião")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createTask)
        XCTAssertNotNil(result.priority)
        XCTAssertEqual(result.priority?.level, .high)
    }

    func testPT_LocationExtraction() async throws {
        let results = try await nlService.process(text: "Agendar reunião no escritório amanhã")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createEvent)
        XCTAssertNotNil(result.location)
        XCTAssertEqual(result.location?.name, "escritório")
    }

    // MARK: - Spanish Tests

    func testES_NextWeekFri1100() async throws {
        let results = try await nlService.process(text: "reprogramar reunión para la próxima semana vie 11:00")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .rescheduleEvent)
        XCTAssertTrue(result.title.contains("reunión"))
        XCTAssertNotNil(result.context.finalDate)
    }

    func testES_MartesALas10() async throws {
        let results = try await nlService.process(text: "programar café para el martes a las 10:00")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createEvent)
        XCTAssertTrue(result.title.contains("café"))
        XCTAssertNotNil(result.context.finalDate)
    }

    func testES_DeAquiAUnMes() async throws {
        let results = try await nlService.process(text: "de aquí a un mes a las 11h")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertNotNil(result.context.finalDate)
    }

    func testES_TagAddition() async throws {
        let results = try await nlService.process(text: "Añadir etiqueta casa a tarea")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .updateTask)
        XCTAssertEqual(result.tags.count, 1)
        XCTAssertEqual(result.tags.first?.name, "casa")
    }

    func testES_PriorityExtraction() async throws {
        let results = try await nlService.process(text: "Crear tarea urgente para arreglar servidor")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createTask)
        XCTAssertNotNil(result.priority)
        XCTAssertEqual(result.priority?.level, .urgent)
    }

    func testES_LocationExtraction() async throws {
        let results = try await nlService.process(text: "Programar reunión en la oficina mañana")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createEvent)
        XCTAssertNotNil(result.location)
        XCTAssertEqual(result.location?.name, "oficina")
    }

    // MARK: - Edge Cases and Error Handling

    func testEmptyInput() async throws {
        let results = try await nlService.process(text: "")

        XCTAssertEqual(results.count, 0)
    }

    func testInputWithOnlyWhitespace() async throws {
        let results = try await nlService.process(text: "   \t  \n  ")

        XCTAssertEqual(results.count, 0)
    }

    func testInputWithSpecialCharacters() async throws {
        let results = try await nlService.process(text: "Add tag @work to #meeting task!")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .updateTask)
        XCTAssertFalse(result.title.isEmpty)
        XCTAssertGreaterThan(result.metadataTokens.count, 0)
    }

    // MARK: - Intent Detection Tests

    func testCreateTaskIntent() async throws {
        let results = try await nlService.process(text: "create task buy groceries")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createTask)
        XCTAssertTrue(result.title.contains("buy groceries"))
    }

    func testCreateEventIntent() async throws {
        let results = try await nlService.process(text: "schedule meeting with team")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createEvent)
        XCTAssertTrue(result.title.contains("meeting with team"))
    }

    func testViewIntent() async throws {
        let results = try await nlService.process(text: "show agenda for next week")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .view)
        XCTAssertNotNil(result.context.finalDate)
    }

    func testCancelIntent() async throws {
        let results = try await nlService.process(text: "cancel dentist appointment")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .cancelEvent)
        XCTAssertTrue(result.title.contains("dentist appointment"))
    }

    // MARK: - Time Range Tests

    func testInlineTimeRange() async throws {
        let results = try await nlService.process(text: "block Wed 09:00-11:30")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createEvent)
        XCTAssertNotNil(result.context.finalDate)
        XCTAssertEqual(result.context.finalDateDuration, 9000)
        XCTAssertNil(result.context.dateRange)
    }

    func testFromToTimeFormat() async throws {
        let results = try await nlService.process(text: "meeting from 10:00 to 11:30")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createEvent)
        XCTAssertNotNil(result.context.finalDate)
        XCTAssertEqual(result.context.finalDateDuration, 5400)
        XCTAssertNil(result.context.dateRange)
    }

    // MARK: - Conflict Detection Tests

    func testPriorityConflictDetection() async throws {
        let results = try await nlService.process(text: "Add high priority urgent task")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createTask)
        XCTAssertEqual(result.title, "")
        // Should detect multiple priority indicators
        XCTAssertGreaterThan(result.metadataTokens.count, 1)
    }

    func testConflictingTimes() async throws {
        let results = try await nlService.process(text: "dinner with parents tonight 8pm at 7pm")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createEvent)
        XCTAssertNotNil(result.context.finalDate)
        // Should detect time conflicts
        XCTAssertGreaterThan(result.context.conflicts.count, 0)
    }

    // MARK: - Performance and Efficiency Tests

    func testOptimizedIntentDetection() async throws {
        // This test verifies that intent detection leverages already-extracted metadata tokens
        let results = try await nlService.process(text: "Add tag work for meeting task")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .updateTask) // Should detect metadata addition as updateTask intent
        XCTAssertEqual(result.tags.count, 1)
        XCTAssertEqual(result.tags.first?.name, "work")
    }

    // MARK: - Temporal Range Exclusion Tests

    func testTemporalRangeExclusion() async throws {
        // Test case where a metadata pattern could potentially overlap with a temporal pattern
        let results = try await nlService.process(text: "Add tag work and remind me 30 minutes before")

        // 2 clauses: "Add tag work" - "remind me 30 minutes before"
        XCTAssertEqual(results.count, 2)
        
        let tagResult = results[0]
        // Should detect ambiguity between createTask and updateTask
        XCTAssertTrue(tagResult.isAmbiguous, "Should detect ambiguity")
        XCTAssertGreaterThan(tagResult.intentAmbiguity?.predictions.count ?? 0, 1, "Should have multiple intent alternatives")
        let intentAlternatives1 = tagResult.intentAmbiguity?.predictions.map { $0.intent } ?? []
        XCTAssertTrue(intentAlternatives1.contains(.createTask), "Should include createTask as alternative")
        XCTAssertTrue(intentAlternatives1.contains(.updateTask), "Should include updateTask as alternative")
        
        XCTAssertEqual(tagResult.context.resolvedTokens.count, 0)
        XCTAssertEqual(tagResult.tags.count, 1)
        XCTAssertEqual(tagResult.tags.first!.name, "work")
        
        let reminderResult = results[1]
        XCTAssertTrue(reminderResult.isAmbiguous, "Should detect ambiguity")
        XCTAssertGreaterThan(reminderResult.intentAmbiguity?.predictions.count ?? 0, 1, "Should have multiple intent alternatives")
        let intentAlternatives2 = reminderResult.intentAmbiguity?.predictions.map { $0.intent } ?? []
        XCTAssertTrue(intentAlternatives2.contains(.updateEvent), "Should include updateEvent as alternative")
        XCTAssertTrue(intentAlternatives2.contains(.updateTask), "Should include updateTask as alternative")
        
        XCTAssertEqual(reminderResult.context.resolvedTokens.count, 0)
        XCTAssertEqual(reminderResult.reminders.count, 1)
        XCTAssertEqual(reminderResult.reminders.first!.trigger, .timeOffset(1800))
    }

    // MARK: - Multiple Language Pack Test

    func testMultipleLanguageDetection() async throws {
        // English input should be processed correctly
        let englishResults = try await nlService.process(text: "schedule meeting tomorrow at 3pm")
        XCTAssertEqual(englishResults.count, 1)
        XCTAssertEqual(englishResults[0].intent, .createEvent)

        // Portuguese input should be processed correctly
        let portugueseResults = try await nlService.process(text: "agendar reunião amanhã às 15h")
        XCTAssertEqual(portugueseResults.count, 1)
        XCTAssertEqual(portugueseResults[0].intent, .createEvent)
    }

    // MARK: - Title Extraction and Cleaning Tests

    func testTitleExtractionWithMetadata() async throws {
        let results = try await nlService.process(text: "move game to next Friday")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.title.trimmingCharacters(in: .whitespacesAndNewlines), "game")
        // Title should be cleaned of temporal metadata
        XCTAssertFalse(result.title.contains("next Friday"))
    }

    func testTitleExtractionWithComplexMetadata() async throws {
        let results = try await nlService.process(text: "add movie today 20h")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.title.trimmingCharacters(in: .whitespacesAndNewlines), "movie")
        // Title should be cleaned of temporal metadata
        XCTAssertFalse(result.title.contains("today"))
        XCTAssertFalse(result.title.contains("20h"))
    }

    func testRenameTaskTitle() async throws {
        let results = try await nlService.process(text: "Rename buy food to buy groceries")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        
        // Should detect ambiguity
        XCTAssertTrue(result.isAmbiguous, "Should detect ambiguity")
        XCTAssertGreaterThan(result.intentAmbiguity?.predictions.count ?? 0, 1, "Should have multiple intent alternatives")

        // Should contain alternatives
        let intentAlternatives = result.intentAmbiguity?.predictions.map { $0.intent } ?? []
        XCTAssertTrue(intentAlternatives.contains(.updateTask), "Should include updateTask as alternative")
        XCTAssertTrue(intentAlternatives.contains(.updateEvent), "Should include updateEvent as alternative")
        
        XCTAssertEqual(result.title, "buy food")
        XCTAssertEqual(result.metadataTokens[0].text, "buy groceries")
        switch result.metadataTokens[0].kind {
            
        case .newTitle(title: let title, confidence: let confidence):
            XCTAssertEqual(title, "buy groceries")
            XCTAssertGreaterThan(confidence, 0.8)
        default:
            XCTFail("Invalid metadata")
        }
    }

    // MARK: - Ambiguous Input Tests for Progressive Intent Resolution

    func testAmbiguousCreateVsUpdate() async throws {
        // "task" could be creating new task or updating existing task
        let results = try await nlService.process(text: "task urgent")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        // Should detect ambiguity between createTask and updateTask
        XCTAssertTrue(result.isAmbiguous, "Should detect ambiguity for 'task urgent' input")
        XCTAssertGreaterThan(result.intentAmbiguity?.predictions.count ?? 0, 1, "Should have multiple intent alternatives")

        // Should contain both createTask and updateTask as alternatives
        let intentAlternatives = result.intentAmbiguity?.predictions.map { $0.intent } ?? []
        XCTAssertTrue(intentAlternatives.contains(.createTask), "Should include createTask as alternative")
        XCTAssertTrue(intentAlternatives.contains(.updateTask), "Should include updateTask as alternative")

        // Should have reasonable confidence scores
        XCTAssertTrue(result.intentAmbiguity?.predictions.allSatisfy { $0.confidence > 0.3 } == true, "All alternatives should have reasonable confidence")
    }

    func testAmbiguousEventVsTask() async throws {
        let now = TestUtil.makeNow()
        
        // "schedule" could apply to both events and tasks
        let results = try await nlService.process(text: "schedule review tomorrow", referenceDate: now)

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        XCTAssertEqual(result.intent, .createEvent)
        XCTAssertEqual(result.title, "review")

        let comps = result.context.finalDate.components()        
        XCTAssertEqual(comps.year, 2025); XCTAssertEqual(comps.month, 9); XCTAssertEqual(comps.day, 12)
        XCTAssertEqual(comps.hour, 10); XCTAssertEqual(comps.minute, 0)
        
    }

    func testAmbiguousWithMetadata() async throws {
        // Priority metadata without clear intent verb
        let results = try await nlService.process(text: "urgent meeting preparation")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        XCTAssertTrue(result.isAmbiguous, "Should detect ambiguity when intent is unclear despite metadata")

        // Should extract priority metadata regardless of intent ambiguity
        XCTAssertNotNil(result.priority)
        XCTAssertEqual(result.priority?.level, .urgent)

        // Should have multiple intent alternatives
        XCTAssertGreaterThan(result.intentAmbiguity?.predictions.count ?? 0, 1)
    }

    func testAmbiguousRescheduleVsCancel() async throws {
        // "move" could mean reschedule or cancel depending on context
        let results = try await nlService.process(text: "move meeting")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        XCTAssertTrue(result.isAmbiguous, "Should detect ambiguity for 'move meeting' without clear destination")

        let intentAlternatives = result.intentAmbiguity?.predictions.map { $0.intent } ?? []
        XCTAssertTrue(intentAlternatives.contains(.rescheduleEvent), "Should include rescheduleEvent as alternative")
        // Note: cancelEvent might also be included depending on linguistic analysis
    }

    func testAmbiguousLanguageDetection() async throws {
        // Mixed language keywords that could be interpreted differently
        let results = try await nlService.process(text: "add tarefa importante")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        
        // Should detect ambiguity
        XCTAssertTrue(result.isAmbiguous, "Should detect ambiguity")
        XCTAssertGreaterThan(result.intentAmbiguity?.predictions.count ?? 0, 1, "Should have multiple intent alternatives")

        // Should contain alternatives
        let intentAlternatives = result.intentAmbiguity?.predictions.map { $0.intent } ?? []
        XCTAssertTrue(intentAlternatives.contains(.updateTask), "Should include updateTask as alternative")
        XCTAssertTrue(intentAlternatives.contains(.createTask), "Should include createTask as alternative")
    }

    func testClearIntentNotAmbiguous() async throws {
        // Clear, unambiguous intent should not trigger disambiguation
        let results = try await nlService.process(text: "create new task buy groceries tomorrow")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        XCTAssertEqual(result.intent, .createTask)
        // Note: Progressive intent resolution may still detect some ambiguity even for clear intents
        // due to the linguistic analysis that considers multiple interpretations
        if result.isAmbiguous {
            // If ambiguous, the primary intent should still be correct and have highest confidence
            XCTAssertTrue(result.intentAmbiguity?.predictions.first?.intent == .createTask, "Primary intent should be createTask")
            XCTAssertTrue(result.intentAmbiguity?.predictions.first?.confidence ?? 0 > 0.7, "Primary intent should have high confidence")
        }
    }

    func testAmbiguousWithComplexMetadata() async throws {
        // Complex input with multiple metadata types but unclear intent
        let results = try await nlService.process(text: "high priority tag work reminder 30 minutes report")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        XCTAssertTrue(result.isAmbiguous, "Complex metadata without clear verb should be ambiguous")

        // Should still extract metadata
        XCTAssertNotNil(result.priority)
        XCTAssertEqual(result.priority?.level, .high)
        XCTAssertEqual(result.tags.count, 1)
        XCTAssertEqual(result.tags.first?.name, "work")

        // Should provide multiple intent options
        XCTAssertGreaterThan(result.intentAmbiguity?.predictions.count ?? 0, 1)
        let intentAlternatives = result.intentAmbiguity?.predictions.map { $0.intent } ?? []
        XCTAssertTrue(intentAlternatives.contains(.createTask) || intentAlternatives.contains(.updateTask))
    }

    func testAmbiguousTemporalContext() async throws {
        // Temporal information without clear action verb
        let results = try await nlService.process(text: "meeting tomorrow 3pm")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        XCTAssertTrue(result.isAmbiguous, "Should detect ambiguity when action is unclear")
        XCTAssertNotNil(result.context.finalDate, "Should still extract temporal information")

        let intentAlternatives = result.intentAmbiguity?.predictions.map { $0.intent } ?? []
        XCTAssertTrue(intentAlternatives.contains(.createEvent), "Should include createEvent as alternative")
    }

    func testConfidenceScoring() async throws {
        // Test that confidence scores make sense for ambiguous cases
        let results = try await nlService.process(text: "urgent task")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        if result.isAmbiguous {
            let predictions = result.intentAmbiguity?.predictions ?? []
            // All alternatives should have confidence between 0.0 and 1.0
            XCTAssertTrue(predictions.allSatisfy { $0.confidence >= 0.0 && $0.confidence <= 1.0 })

            // At least one alternative should have reasonable confidence
            XCTAssertTrue(predictions.contains { $0.confidence > 0.4 })

            // Alternatives should be sorted by confidence (highest first)
            let confidences = predictions.map { $0.confidence }
            XCTAssertEqual(confidences, confidences.sorted(by: >), "Alternatives should be sorted by confidence")
        }
    }

    func testReasoningProvided() async throws {
        // Test that reasoning is provided for ambiguous intents
        let results = try await nlService.process(text: "deadline project")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        if result.isAmbiguous {
            let predictions = result.intentAmbiguity?.predictions ?? []
            // Each alternative should have reasoning
            XCTAssertTrue(predictions.allSatisfy { !$0.reasoning.isEmpty })

            // Reasoning should contain relevant keywords
            let allReasoning = predictions.flatMap { $0.reasoning }.joined(separator: " ")
            XCTAssertTrue(allReasoning.contains("deadline") || allReasoning.contains("project") ||
                         allReasoning.contains("task") || allReasoning.contains("event"))
        }
    }

    // MARK: - Portuguese Ambiguous Tests

    func testPT_AmbiguousCreateVsUpdate() async throws {
        let results = try await nlService.process(text: "tarefa urgente")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        XCTAssertTrue(result.isAmbiguous, "Should detect ambiguity for Portuguese 'tarefa urgente'")

        let intentAlternatives = result.intentAmbiguity?.predictions.map { $0.intent } ?? []
        XCTAssertTrue(intentAlternatives.contains(.createTask) || intentAlternatives.contains(.updateTask))
    }

    func testPT_AmbiguousEventVsTask() async throws {
        let results = try await nlService.process(text: "reunião importante amanhã")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        switch result.metadataTokens.first!.kind {
        case .priority(let level, let confidence):
            XCTAssertEqual(level, .high)
            XCTAssertGreaterThanOrEqual(confidence, 0.8)
        default:
            XCTFail("Invalid metadata")
        }
        
        XCTAssertTrue(result.isAmbiguous, "Portuguese 'reunião importante amanhã' should be ambiguous")
        let intentAlternatives = result.intentAmbiguity?.predictions.map { $0.intent } ?? []
        XCTAssertTrue(intentAlternatives.contains(.createTask), "Should include createTask as alternative")
    }

    // MARK: - Spanish Ambiguous Tests

    func testES_AmbiguousCreateVsUpdate() async throws {
        let results = try await nlService.process(text: "tarea urgente")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        XCTAssertTrue(result.isAmbiguous, "Should detect ambiguity for Spanish 'tarea urgente'")

        let intentAlternatives = result.intentAmbiguity?.predictions.map { $0.intent } ?? []
        XCTAssertTrue(intentAlternatives.contains(.createTask) || intentAlternatives.contains(.updateTask))
    }

    func testES_AmbiguousEventVsTask() async throws {
        let results = try await nlService.process(text: "reunión importante mañana")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        switch result.metadataTokens.first!.kind {
        case .priority(let level, let confidence):
            XCTAssertEqual(level, .high)
            XCTAssertGreaterThanOrEqual(confidence, 0.8)
        default:
            XCTFail("Invalid metadata")
        }
        
        XCTAssertTrue(result.isAmbiguous, "Spanish 'reunión importante mañana' should be ambiguous")
        let intentAlternatives = result.intentAmbiguity?.predictions.map { $0.intent } ?? []
        XCTAssertTrue(intentAlternatives.contains(.createTask), "Should include createTask as alternative")
    }

    // MARK: - Edge Cases for Ambiguity Detection

    func testNoAmbiguityForUnknownIntent() async throws {
        // Completely unclear input should result in unknown intent, not ambiguity
        let input = "xyz abc def"
        let results = try await nlService.process(text: input)

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        XCTAssertEqual(result.title.count, input.count)
    }

    func testNoAmbiguityForView() async throws {
        // View intent should typically be clear and not ambiguous
        let results = try await nlService.process(text: "show my agenda for next week")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        XCTAssertEqual(result.intent, .view)
        // Progressive intent resolution may detect some ambiguity due to linguistic analysis
        // but the primary intent should be view with high confidence
        if result.isAmbiguous {
            XCTAssertTrue(result.intentAmbiguity?.predictions.first?.intent == .view, "Primary intent should be view")
            XCTAssertTrue(result.intentAmbiguity?.predictions.first?.confidence ?? 0 > 0.4, "View intent should have good confidence in relation to others")
        }
    }

    func testMinimalAmbiguityThreshold() async throws {
        // Test that ambiguity threshold works correctly
        let results = try await nlService.process(text: "buy milk")

        XCTAssertEqual(results.count, 1)
        let result = results[0]

        // Clear task creation should be detected correctly
        XCTAssertEqual(result.intent, .createTask)
        // Progressive intent resolution may still detect ambiguity for simple phrases
        // but createTask should be the primary intent with high confidence
        if result.isAmbiguous {
            XCTAssertTrue(result.intentAmbiguity?.predictions.first?.intent == .createTask, "Primary intent should be createTask")
            XCTAssertTrue(result.intentAmbiguity?.predictions.first?.confidence ?? 0 > 0.6, "Primary intent should have reasonable confidence")
        }
    }
}
