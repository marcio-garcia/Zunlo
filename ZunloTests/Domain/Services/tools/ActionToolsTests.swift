//
//  ActionToolsTests.swift
//  ZunloTests
//
//  Created by Marcio Garcia on 9/19/25.
//

import XCTest
import SmartParseKit
@testable import Zunlo

final class ActionToolsTests: XCTestCase {
    private var nlService: NLService!
    private var calendar: Calendar!
    private var mockEventStore: MockEventStore!
    private var mockTaskStore: MockTaskStore!
    private var userId = UUID()

    // Tools to test
    private var cancelEventTool: CancelEventTool!
    private var rescheduleEventTool: RescheduleEventTool!
    private var updateEventTool: UpdateEventTool!
    private var createEventTool: CreateEventTool!
    private var createTaskTool: CreateTaskTool!
    private var updateTaskTool: UpdateTaskTool!
    private var cancelTaskTool: CancelTaskTool!
    private var rescheduleTaskTool: RescheduleTaskTool!
    private var planDayTool: PlanDayTool!
    private var planWeekTool: PlanWeekTool!
    private var showAgendaTool: ShowAgendaTool!
    private var moreInfoTool: MoreInfoTool!
    private var unknownTool: UnknownTool!

    private let now = TestUtil.makeNow()
    
    override func setUp() {
        super.setUp()
        calendar = TestUtil.calendarSP()

        // Setup NL Service
        let parser = TemporalComposer(prefs: TestUtil.temporalComposerPrefs())
        let intentDetector = AppleIntentDetector()
        nlService = NLService(parser: parser, intentDetector: intentDetector, calendar: calendar)

        // Setup mock stores
        mockEventStore = MockEventStore()
        mockTaskStore = MockTaskStore()
        
        // Initialize tools
        cancelEventTool = CancelEventTool(events: mockEventStore, referenceDate: now, calendar: calendar)
        rescheduleEventTool = RescheduleEventTool(events: mockEventStore, referenceDate: now, calendar: calendar)
        updateEventTool = UpdateEventTool(events: mockEventStore, referenceDate: now, calendar: calendar)
        createEventTool = CreateEventTool(events: mockEventStore, userId: userId, calendar: calendar)
        createTaskTool = CreateTaskTool(tasks: mockTaskStore, userId: userId, referenceDate: now, calendar: calendar)
        updateTaskTool = UpdateTaskTool(tasks: mockTaskStore, referenceDate: now, calendar: calendar)
        cancelTaskTool = CancelTaskTool(tasks: mockTaskStore, referenceDate: now, calendar: calendar)
        rescheduleTaskTool = RescheduleTaskTool(tasks: mockTaskStore, referenceDate: now, calendar: calendar)
        planDayTool = PlanDayTool(events: mockEventStore, calendar: calendar)
        planWeekTool = PlanWeekTool(events: mockEventStore, calendar: calendar)
        showAgendaTool = ShowAgendaTool(events: mockEventStore, calendar: calendar)
        moreInfoTool = MoreInfoTool(events: mockEventStore, tasks: mockTaskStore, calendar: calendar)
        unknownTool = UnknownTool()
    }

    override func tearDown() {
        nlService = nil
        calendar = nil
        mockEventStore = nil
        mockTaskStore = nil
        super.tearDown()
    }

    // MARK: - Event Tool Tests

    func testCancelEventTool() async throws {
        // Setup test data
        let testEvent = mockEventStore.createTestEvent(title: "Team Meeting", startHour: 14, referenceDate: now, calendar: calendar)
        mockEventStore.mockOccurrences = [testEvent]

        // Get parse result
        let parseResults = try await nlService.process(text: "cancel team meeting today", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await cancelEventTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertTrue(parseResult.isAmbiguous)
        XCTAssertEqual(result.action, .canceledEvent(id: testEvent.id))
        XCTAssertFalse(result.needsDisambiguation)
        XCTAssertTrue(result.message?.contains("Cancelled 'Team Meeting'") == true)
    }

    func testRescheduleEventTool() async throws {
        // Setup test data
        let testEvent = mockEventStore.createTestEvent(title: "Doctor Appointment", startHour: 10, referenceDate: now, calendar: calendar)
        mockEventStore.mockOccurrences = [testEvent]

        // Get parse result
        let parseResults = try await nlService.process(text: "reschedule doctor appointment to 3pm", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await rescheduleEventTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertEqual(result.intent, .rescheduleEvent)
        XCTAssertFalse(result.needsDisambiguation)
        if case .rescheduledEvent(let eventId, let start, _) = result.action {
            XCTAssertEqual(eventId, testEvent.eventId)
            XCTAssertEqual(calendar.component(.hour, from: start), 15) // 3pm
        } else {
            XCTFail("Expected rescheduledEvent action")
        }
    }
    
    func testRescheduleEventToWeekday() async throws {
        // Setup test data
        let testEvent = mockEventStore.createTestEvent(title: "reuniao", startHour: 10, referenceDate: now, calendar: calendar)
        mockEventStore.mockOccurrences = [testEvent]

        // Get parse result
        let parseResults = try await nlService.process(text: "reschedule reunião to Monday", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await rescheduleEventTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertEqual(result.intent, .rescheduleEvent)
        XCTAssertFalse(result.needsDisambiguation)
        if case .rescheduledEvent(let eventId, let start, _) = result.action {
            XCTAssertEqual(eventId, testEvent.eventId)
            XCTAssertEqual(calendar.component(.hour, from: start), 10)
        } else {
            XCTFail("Expected rescheduledEvent action")
        }
    }
    
    func testPT_CreateAndRescheduleEventTomorrow() async throws {

        var eventId = UUID()
        
        // Create event
        let createParseResults = try await nlService.process(text: "crie reuniao amanha", referenceDate: now)
        
        XCTAssertEqual(createParseResults.count, 1)
        let createParseResult = createParseResults[0]
        let createToolResult = await createEventTool.perform(CommandContext.from(parseResult: createParseResult))
        
        XCTAssertEqual(createToolResult.intent, .createEvent)
        if case .createdEvent(let id) = createToolResult.action {
            eventId = id
        } else {
            XCTFail("Expected createdEvent action")
        }
        XCTAssertFalse(createToolResult.needsDisambiguation)
        XCTAssertTrue(createToolResult.message?.contains("Created event") == true)
        

        // Reschedule event
        let parseResults = try await nlService.process(text: "mova reuniao de amanha para as 11h", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await rescheduleEventTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertEqual(result.intent, .rescheduleEvent)
        XCTAssertFalse(result.needsDisambiguation)
        if case .rescheduledEvent(let id, let start, _) = result.action {
            XCTAssertEqual(id, eventId)
            XCTAssertEqual(calendar.component(.hour, from: start), 11)
        } else {
            XCTFail("Expected rescheduledEvent action")
        }
    }

    func testUpdateEventTool() async throws {
        // Setup test data
        let testEvent = mockEventStore.createTestEvent(title: "Project Review", startHour: 9, referenceDate: now, calendar: calendar)
        mockEventStore.mockOccurrences = [testEvent]

        // Get parse result
        let parseResults = try await nlService.process(text: "update project review title to 'Sprint Review'", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await updateEventTool.perform(CommandContext.from(parseResult: parseResult))

        if !parseResult.isAmbiguous {
            XCTAssertEqual(result.intent, .updateEvent)
        }
        XCTAssertEqual(result.action, .updatedEvent(id: testEvent.id))
        XCTAssertFalse(result.needsDisambiguation)
    }

    func testCreateEventTool() async throws {
        // Get parse result
        let parseResults = try await nlService.process(text: "create meeting tomorrow at 2pm", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await createEventTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertEqual(result.intent, .createEvent)
        if case .createdEvent = result.action {
            // Success
        } else {
            XCTFail("Expected createdEvent action")
        }
        XCTAssertFalse(result.needsDisambiguation)
        XCTAssertTrue(result.message?.contains("Created event") == true)
    }

    // MARK: - Task Tool Tests

    func testCreateTaskTool() async throws {
        // Get parse result
        let parseResults = try await nlService.process(text: "create task buy groceries due tomorrow", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await createTaskTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertEqual(result.intent, .createTask)
        if case .createdTask = result.action {
            // Success
        } else {
            XCTFail("Expected createdTask action")
        }
        XCTAssertFalse(result.needsDisambiguation)
        XCTAssertTrue(result.message?.contains("Created task") == true)
    }

    func testCancelTaskTool() async throws {
        // Setup test data
        let testTask = createTestTask(title: "Buy Milk", referenceDate: now)
        mockTaskStore.mockTasks = [testTask]

        // Get parse result
        let parseResults = try await nlService.process(text: "cancel buy milk task", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await cancelTaskTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertEqual(result.intent, .cancelTask)
        XCTAssertEqual(result.action, .canceledTask(id: testTask.id))
        XCTAssertFalse(result.needsDisambiguation)
        XCTAssertTrue(result.message?.contains("Cancelled task 'Buy Milk'") == true)
    }

    func testUpdateTaskTool() async throws {
        // Setup test data
        let testTask = createTestTask(title: "Write Report", referenceDate: now)
        mockTaskStore.mockTasks = [testTask]

        // Get parse result
        let parseResults = try await nlService.process(text: "update write report task title to \"Write Monthly Report\"", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await updateTaskTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertEqual(result.intent, .updateTask)
        XCTAssertEqual(result.action, .updatedTask(id: testTask.id))
        XCTAssertFalse(result.needsDisambiguation)
    }

    func testRescheduleTaskTool() async throws {
        // Setup test data
        let testTask = createTestTask(title: "Submit Assignment", referenceDate: now)
        mockTaskStore.mockTasks = [testTask]

        // Get parse result
        let parseResults = try await nlService.process(text: "reschedule submit assignment task to Monday", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await rescheduleTaskTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertEqual(result.intent, .rescheduleTask)
        if case .rescheduledTask(let taskId, let dueDate) = result.action {
            XCTAssertEqual(taskId, testTask.id)
            XCTAssertNotNil(dueDate)
        } else {
            XCTFail("Expected rescheduledTask action")
        }
        XCTAssertFalse(result.needsDisambiguation)
    }

    // MARK: - Planning Tool Tests

    func testPlanDayTool() async throws {
        // Setup test data
        let testEvent = mockEventStore.createTestEvent(title: "Morning Standup", startHour: 9, referenceDate: now, calendar: calendar)
        mockEventStore.mockOccurrences = [testEvent]

        // Get parse result
        let parseResults = try await nlService.process(text: "plan my day today", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await planDayTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertEqual(result.intent, .plan)
        if case .plannedDay(let range, let occurrences) = result.action {
            XCTAssertTrue(range.contains(testEvent.startDate))
            XCTAssertEqual(occurrences.count, 1)
        } else {
            XCTFail("Expected plannedDay action")
        }
        XCTAssertFalse(result.needsDisambiguation)
    }

    func testPlanWeekTool() async throws {
        // Setup test data
        let testEvent = mockEventStore.createTestEvent(title: "Weekly Review", startHour: 15, referenceDate: now, calendar: calendar)
        mockEventStore.mockOccurrences = [testEvent]

        // Get parse result
        let parseResults = try await nlService.process(text: "show my week plan", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await planWeekTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertTrue(parseResult.isAmbiguous)
        if case .plannedWeek(let range, let occurrences) = result.action {
            XCTAssertTrue(range.contains(testEvent.startDate))
            XCTAssertEqual(occurrences.count, 1)
        } else {
            XCTFail("Expected plannedWeek action")
        }
        XCTAssertFalse(result.needsDisambiguation)
    }

    func testShowAgendaTool() async throws {
        // Setup test data
        let testEvent = mockEventStore.createTestEvent(title: "Client Call", startHour: 11, referenceDate: now, calendar: calendar)
        mockEventStore.mockOccurrences = [testEvent]

        // Get parse result
        let parseResults = try await nlService.process(text: "show my agenda for today", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await showAgendaTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertEqual(result.intent, .view)
        if case .agenda(let range, let occurrences) = result.action {
            XCTAssertTrue(range.contains(testEvent.startDate))
            XCTAssertEqual(occurrences.count, 1)
        } else {
            XCTFail("Expected agenda action")
        }
        XCTAssertFalse(result.needsDisambiguation)
    }

    // MARK: - Utility Tool Tests

    func testMoreInfoTool() async throws {
        // Setup test data
        let testEvent = mockEventStore.createTestEvent(title: "Team Building", startHour: 14, referenceDate: now, calendar: calendar)
        let testTask = createTestTask(title: "Prepare Presentation", referenceDate: now)
        mockEventStore.mockOccurrences = [testEvent]
        mockTaskStore.mockTasks = [testTask]

        // Get parse result
        let parseResults = try await nlService.process(text: "more info about team building", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await moreInfoTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertEqual(result.intent, .unknown)
        if case .info(let message) = result.action {
            XCTAssertTrue(message.contains("team building"))
        } else {
            XCTFail("Expected info action")
        }
        XCTAssertFalse(result.needsDisambiguation)
    }

    func testUnknownTool() async throws {
        // Get parse result - this should be unknown
        let parseResults = try await nlService.process(text: "xyz random nonsense abc", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await unknownTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertEqual(result.intent, .unknown)
        if case .info(let message) = result.action {
            XCTAssertTrue(message.contains("It seems you want"))
        } else {
            XCTFail("Expected info action")
        }
        XCTAssertFalse(result.needsDisambiguation)
    }

    // MARK: - Disambiguation Tests

    func testEventDisambiguation() async throws {
        // Setup multiple events with similar titles
        let event1 = mockEventStore.createTestEvent(title: "Meeting", startHour: 9, referenceDate: now, calendar: calendar)
        let event2 = mockEventStore.createTestEvent(title: "Meeting", startHour: 14, referenceDate: now, calendar: calendar)
        mockEventStore.mockOccurrences = [event1, event2]

        // Get parse result
        let parseResults = try await nlService.process(text: "cancel meeting today", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await cancelEventTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertTrue(parseResult.isAmbiguous)
        XCTAssertTrue(result.needsDisambiguation)
        XCTAssertEqual(result.options.count, 2)
    }

    func testTaskDisambiguation() async throws {
        // Setup multiple tasks with similar titles
        let task1 = createTestTask(title: "Review", referenceDate: now)
        let task2 = createTestTask(title: "Review Code", referenceDate: now)
        mockTaskStore.mockTasks = [task1, task2]

        // Get parse result
        let parseResults = try await nlService.process(text: "cancel review task", referenceDate: now)
        XCTAssertEqual(parseResults.count, 1)
        let parseResult = parseResults[0]

        // Test the tool
        let result = await cancelTaskTool.perform(CommandContext.from(parseResult: parseResult))

        XCTAssertEqual(result.intent, .cancelTask)
        XCTAssertTrue(result.needsDisambiguation)
        XCTAssertEqual(result.options.count, 2)
    }

    // MARK: - Helper Methods

    private func createTestTask(title: String, referenceDate: Date) -> UserTask {
        return UserTask(
            id: UUID(),
            userId: UUID(),
            title: title,
            notes: nil,
            isCompleted: false,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            dueDate: referenceDate.addingTimeInterval(86400),
            priority: .medium
        )
    }
}

// MARK: - Mock Stores

class MockEventStore: EventStore {
    var mockOccurrences: [EventOccurrence] = []
    var mockEvents: [Event] = []
    var mockRules: [RecurrenceRule] = []
    var mockOverrides: [EventOverride] = []
    
    func makeEvent(title: String, start: Date, end: Date) -> Event? {
        return nil
    }

    func fetchEvent(by id: UUID) async throws -> Event? {
        return nil
    }

    func fetchOccurrences() async throws -> [EventOccurrence] {
        return mockOccurrences
    }

    func fetchOccurrences(id: UUID) async throws -> EventOccurrence? {
        return mockOccurrences.first { $0.id == id }
    }

    func fetchOccurrences(in range: Range<Date>) async throws -> [EventOccurrence] {
        return mockOccurrences.filter { event in
            range.contains(event.startDate) || range.contains(event.endDate)
        }
    }

    func upsert(_ event: Event) async throws {}

    func add(_ input: AddEventInput) async throws {
        let occ = EventOccurrence(
            id: input.id,
            userId: input.userId,
            eventId: input.id,
            title: input.title,
            notes: input.notes,
            startDate: input.startDate,
            endDate: input.endDate,
            isRecurring: input.isRecurring,
            location: input.location,
            color: input.color,
            reminderTriggers: input.reminderTriggers,
            isOverride: false,
            isCancelled: input.isCancelled,
            updatedAt: Date(),
            createdAt: Date(),
            overrides: [],
            recurrence_rules: [],
            deletedAt: nil,
            needsSync: true,
            isFakeOccForEmptyToday: false,
            version: nil
        )
        mockOccurrences.append(occ)
    }

    func editAll(event: EventOccurrence, with input: EditEventInput, oldRule: RecurrenceRule?) async throws {
        guard let index = mockOccurrences.firstIndex(where: { $0.id == event.id }) else {
            return
        }
        
        let newEvent = createEvent(
            id: event.id,
            userId: event.userId,
            eventId: event.eventId,
            title: input.title,
            startDate: input.startDate,
            endDate: input.endDate,
            updatedAt: Date(),
            createdAt: Date()
        )
        
        mockOccurrences[index] = newEvent
    }

    func editSingleOccurrence(parent: EventOccurrence, occurrence: EventOccurrence, with input: EditEventInput) async throws {}

    func editOverride(_ override: EventOverride, with input: EditEventInput) async throws {}

    func editFuture(parent: EventOccurrence, startingFrom occurrence: EventOccurrence, with input: EditEventInput) async throws {}

    func delete(id: UUID) async throws {
        mockOccurrences.removeAll { $0.id == id }
    }
    
    func createTestEvent(title: String, startHour: Int, referenceDate: Date, calendar: Calendar) -> EventOccurrence {
        let startOfDay = referenceDate.startOfDay(calendar: calendar)
        let startDate = calendar.date(byAdding: .hour, value: startHour, to: startOfDay)!
        let endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)!
        
        return createEvent(
            id: UUID(),
            userId: UUID(),
            eventId: UUID(),
            title: title,
            startDate: startDate,
            endDate: endDate,
            updatedAt: referenceDate,
            createdAt: referenceDate
        )
    }
    
    func createEvent(
        id: UUID, userId: UUID, eventId: UUID, title: String, startDate: Date, endDate: Date,
        updatedAt: Date,
        createdAt: Date) -> EventOccurrence
    {
        return EventOccurrence(
            id: UUID(),
            userId: UUID(),
            eventId: UUID(),
            title: title,
            notes: nil,
            startDate: startDate,
            endDate: endDate,
            isRecurring: false,
            location: nil,
            color: EventColor.softOrange,
            reminderTriggers: [],
            isOverride: false,
            isCancelled: false,
            updatedAt: updatedAt,
            createdAt: createdAt,
            overrides: [],
            recurrence_rules: [],
            deletedAt: nil,
            needsSync: true,
            isFakeOccForEmptyToday: false,
            version: nil
        )
    }
}

class MockTaskStore: TaskStore {
    var mockTasks: [UserTask] = []

    func fetchAll() async throws -> [UserTask] {
        return mockTasks
    }

    func fetchTask(by id: UUID) async throws -> UserTask? {
        return mockTasks.first { $0.id == id }
    }

    func delete(taskId: UUID) async throws {
        mockTasks.removeAll { $0.id == taskId }
    }
    
    func fetchTasks(filteredBy filter: Zunlo.TaskFilter?) async throws -> [Zunlo.UserTask] {
        return []
    }
    
    func upsert(_ task: Zunlo.UserTask) async throws {
        let newTask = UserTask(
            id: task.id,
            userId: task.id,
            title: task.title,
            notes: task.notes,
            isCompleted: task.isCompleted,
            dueDate: task.dueDate,
            priority: task.priority
        )
        mockTasks.append(newTask)
    }
    
    func insert(title: String, due: Date?) async throws -> UUID {
        return UUID()
    }
    
    func update(id: UUID, title: String?, dueDate: Date?, tags: [String]?, reminderTriggers: [ReminderTrigger]?, priority: UserTaskPriority?, notes: String?) async throws {
        if var task = mockTasks.first(where: { $0.id == id }) {
            if let due = dueDate { task.dueDate = due }
            if let t = title { task.title = t }
            if let tg = tags { task.tags = tg.map({ Tag(id: UUID(), text: $0, color: "", selected: false) })}
            if let r = reminderTriggers { task.reminderTriggers = r }
            if let p = priority { task.priority = p }
            if let n = notes { task.notes = n }
            mockTasks.append(task)
        }
    }
}
