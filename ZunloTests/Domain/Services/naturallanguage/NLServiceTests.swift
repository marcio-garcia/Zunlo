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

// MARK: - Mock Classes for Testing

class MockAppleIntentDetector: IntentDetector {
    var mockLanguage: NLLanguage = .english
    var mockIntent: Intent = .unknown

    func detectLanguage(_ text: String) -> NLLanguage {
        // Detect language based on keywords for testing
        if text.contains("reunião") || text.contains("tarefa") || text.contains("adicionar") {
            return .portuguese
        } else if text.contains("reunión") || text.contains("tarea") || text.contains("añadir") {
            return .spanish
        }
        return .english
    }

    func classify(_ text: String) -> Intent {
        let lowercased = text.lowercased()

        // Check for metadata addition patterns first (they should be updateTask)
        if lowercased.contains("add tag") || lowercased.contains("set priority") || lowercased.contains("add reminder") ||
           lowercased.contains("adicionar tag") || lowercased.contains("añadir etiqueta") ||
           lowercased.contains("adicionar etiqueta") || lowercased.contains("definir prioridade") ||
           lowercased.contains("crear tarea urgente") || lowercased.contains("alta prioridade") {
            return .updateTask
        }

        // English patterns
        if lowercased.contains("create") || lowercased.contains("add") || lowercased.contains("schedule") {
            if lowercased.contains("meeting") || lowercased.contains("appointment") || lowercased.contains("event") {
                return .createEvent
            } else if lowercased.contains("task") || lowercased.contains("todo") {
                return .createTask
            }
            return .createTask
        }

        if lowercased.contains("move") || lowercased.contains("reschedule") || lowercased.contains("push") {
            if lowercased.contains("meeting") || lowercased.contains("appointment") || lowercased.contains("event") {
                return .rescheduleEvent
            } else if lowercased.contains("task") {
                return .rescheduleTask
            }
            return .rescheduleEvent
        }

        if lowercased.contains("cancel") || lowercased.contains("delete") || lowercased.contains("remove") {
            if lowercased.contains("meeting") || lowercased.contains("appointment") || lowercased.contains("event") {
                return .cancelEvent
            } else if lowercased.contains("task") {
                return .cancelTask
            }
            return .cancelEvent
        }

        if lowercased.contains("show") || lowercased.contains("view") || lowercased.contains("agenda") {
            return .view
        }

        // Portuguese patterns
        if lowercased.contains("criar") || lowercased.contains("adicionar") || lowercased.contains("agendar") || lowercased.contains("marcar") {
            if lowercased.contains("reunião") || lowercased.contains("compromisso") || lowercased.contains("evento") {
                return .createEvent
            } else if lowercased.contains("tarefa") {
                return .createTask
            }
            return .createTask
        }

        if lowercased.contains("mover") || lowercased.contains("remarcar") {
            if lowercased.contains("reunião") || lowercased.contains("compromisso") || lowercased.contains("evento") {
                return .rescheduleEvent
            } else if lowercased.contains("tarefa") {
                return .rescheduleTask
            }
            return .rescheduleEvent
        }

        // Spanish patterns
        if lowercased.contains("crear") || lowercased.contains("añadir") || lowercased.contains("programar") {
            if lowercased.contains("reunión") || lowercased.contains("cita") || lowercased.contains("evento") {
                return .createEvent
            } else if lowercased.contains("tarea") {
                return .createTask
            }
            return .createTask
        }

        if lowercased.contains("mover") || lowercased.contains("reprogramar") {
            if lowercased.contains("reunión") || lowercased.contains("cita") || lowercased.contains("evento") {
                return .rescheduleEvent
            } else if lowercased.contains("tarea") {
                return .rescheduleTask
            }
            return .rescheduleEvent
        }

        return .unknown
    }
}

final class NLServiceTests: XCTestCase {
    private var nlService: NLService!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = TestUtil.calendarSP()
        let parser = TemporalComposer(prefs: TestUtil.prefs())
        let engine = MockAppleIntentDetector()
        nlService = NLService(parser: parser, engine: engine, calendar: calendar)
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
        XCTAssertEqual(result.intent, .rescheduleEvent)
        XCTAssertEqual(result.title.trimmingCharacters(in: .whitespacesAndNewlines), "game")
        XCTAssertNotNil(result.context.finalDate)
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
        XCTAssertEqual(result.intent, .rescheduleTask)
        XCTAssertTrue(result.title.contains("do laundry"))
        XCTAssertNotNil(result.context.finalDate)
    }

    // MARK: - Metadata Extraction Tests

    func testSimpleTagExtraction() async throws {
        let results = try await nlService.process(text: "Add tag home to pay bills tomorrow")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .updateTask)
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
        XCTAssertNotNil(result.priority)
        XCTAssertEqual(result.priority?.level, .urgent)
        XCTAssertGreaterThan(result.priority?.confidence ?? 0, 0.8)
    }

    func testReminderTimeOffsetExtraction() async throws {
        let results = try await nlService.process(text: "Remind me 30 minutes before the dentist appointment")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .updateTask)
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
        let results = try await nlService.process(text: "Add task note: Remember to bring documents for the meeting")

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
        XCTAssertEqual(result.intent, .updateTask)

        // Should extract tag, priority, location, reminder
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
        XCTAssertEqual(result.intent, .rescheduleEvent)
        XCTAssertEqual(result.title.trimmingCharacters(in: .whitespacesAndNewlines), "jogo")
        XCTAssertNotNil(result.context.finalDate)
    }

    func testPT_TagAddition() async throws {
        let results = try await nlService.process(text: "Adicionar tag trabalho para tarefa")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .updateTask)
        XCTAssertEqual(result.tags.count, 1)
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

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .unknown)
        XCTAssertEqual(result.title.trimmingCharacters(in: .whitespacesAndNewlines), "")
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

    func testRescheduleIntent() async throws {
        let results = try await nlService.process(text: "move team meeting to next Friday")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .rescheduleEvent)
        XCTAssertTrue(result.title.contains("team meeting"))
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
        XCTAssertNotNil(result.context.dateRange)
    }

    func testFromToTimeFormat() async throws {
        let results = try await nlService.process(text: "meeting from 10:00 to 11:30")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createEvent)
        XCTAssertNotNil(result.context.finalDate)
        XCTAssertNotNil(result.context.dateRange)
    }

    // MARK: - Conflict Detection Tests

    func testPriorityConflictDetection() async throws {
        let results = try await nlService.process(text: "Add high priority urgent task")

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .createTask)
        // Should detect multiple priority indicators as a conflict
        XCTAssertGreaterThan(result.context.conflicts.count, 0)
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

        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.intent, .updateTask)
        XCTAssertEqual(result.tags.count, 1)
        XCTAssertEqual(result.tags.first?.name, "work")
        // Should extract reminder without overlap issues
        XCTAssertEqual(result.reminders.count, 1)
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
        XCTAssertEqual(result.intent, .updateTask)
        XCTAssertEqual(result.title.trimmingCharacters(in: .whitespacesAndNewlines), "buy food")
    }
}

// MARK: - Test Utilities Extension

extension NLServiceTests {
    enum TestUtil {
        static func prefs() -> Preferences {
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
    }
}
