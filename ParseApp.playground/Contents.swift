import Foundation
import SmartParseKit

// Your Event model from Zunlo
struct Event: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: UUID
    var title: String
    var notes: String?
    var startDate: Date
    var endDate: Date?
    var isRecurring: Bool
    var location: String?
    var createdAt: Date
    var updatedAt: Date
    var color: EventColor
    var reminderTriggers: [ReminderTrigger]?
    var deletedAt: Date?
    var needsSync: Bool
    var version: Int?
}

// Make it usable by SmartParseKit’s rescheduler
extension Event: EventLike {}

// MARK: - Dummy TaskStore

final class InMemoryTaskStore: TaskStore {
    struct Task { var title: String; var due: Date? }
    private(set) var tasksDB: [Task] = []

    func createTask(title: String, due: Date?, userInfo: [String : Any]?) async throws -> Any {
        tasksDB.append(Task(title: title, due: due))
        return title
    }

    func tasks(dueIn range: Range<Date>) async throws -> [Any] {
        tasksDB.filter { t in
            guard let d = t.due else { return false }
            return range.contains(d)
        }
    }
}

// MARK: - Dummy EventStore

final class InMemoryEventStore: EventStore {
    typealias E = Event
    private(set) var eventsDB: [Event] = []

    @discardableResult
    func createEvent(title: String, start: Date, end: Date, isRecurring: Bool) async throws -> Event {
        let now = Date()
        let e = Event(
            id: UUID(),
            userId: UUID(),
            title: title,
            notes: nil,
            startDate: start,
            endDate: end,
            isRecurring: isRecurring,
            location: nil,
            createdAt: now,
            updatedAt: now,
            color: .blue,                 // whatever default fits your app
            reminderTriggers: nil,
            deletedAt: nil,
            needsSync: true,
            version: 1
        )
        eventsDB.append(e)
        return e
    }

    func updateEvent(id: UUID, start: Date, end: Date) async throws {
        guard let idx = eventsDB.firstIndex(where: { $0.id == id }) else { return }
        eventsDB[idx].startDate = start
        eventsDB[idx].endDate = end
        eventsDB[idx].updatedAt = Date()
        eventsDB[idx].needsSync = true
        eventsDB[idx].version = (eventsDB[idx].version ?? 0) + 1
    }

    func events(in range: Range<Date>) async throws -> [Event] {
        eventsDB.filter { ev in
            range.contains(ev.startDate) || (ev.endDate.map(range.contains) ?? false)
        }
    }
}

// Load your intent model (App bundle)
let engine = IntentEngine(modelURL: Bundle.main.url(forResource: "ZunloIntents", withExtension: "mlmodelc"))

// If you embedded the model *inside* the package as a resource, you could expose a helper like:
// let engine = IntentEngine.bundled()

let parser = CommandParser(engine: engine)
let taskStore = InMemoryTaskStore()
let eventStore = InMemoryEventStore()
let executor = CommandExecutor(tasks: taskStore, events: eventStore)

// Seed a couple of events so rescheduling has something to move
let calendar = Calendar.current
let today9 = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: Date())!
let today10 = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
let today1030 = calendar.date(bySettingHour: 10, minute: 30, second: 0, of: Date())!

Task {
    _ = try await eventStore.createEvent(title: "Team Standup", start: today9, end: today10, isRecurring: true)
    _ = try await eventStore.createEvent(title: "1:1 with Ana", start: today10, end: today1030, isRecurring: false)

    // Helper to run/print
    func run(_ text: String) async {
        let parsed = parser.parse(text)
        do {
            let result = try await executor.execute(parsed)
            print("» \(text)\n  intent=\(parsed.intent) title=\(parsed.title ?? "nil") when=\(parsed.when?.description ?? "nil")")
            print("  → \(result.message)\n")
        } catch {
            print("Command failed: \(error)")
        }
    }

    // SAMPLE INPUTS
    await run("create task to buy cat food tomorrow")
    await run("create event coffee with Ana next Friday 10am")
    await run("reschedule today's standup to 10am")
    await run("help me plan my week")
    await run("change event title to Team All-Hands")       // update_event example
    await run("show agenda for tomorrow")                   // show_agenda example
}

//» create task to buy cat food tomorrow
//  intent=create_task title=buy cat food when=2025-09-01 09:00:00 +0000
//  → Task ‘buy cat food’ created for Sep 1, 2025.
//
//» create event coffee with Ana next Friday 10am
//  intent=create_event title=coffee with ana when=2025-09-05 10:00:00 +0000
//  → Event ‘coffee with ana’ scheduled at Sep 5, 2025 at 10:00 AM.
//
//» reschedule today's standup to 10am
//  intent=update_reschedule title=standup when=2025-08-31 10:00:00 +0000
//  → ‘Team Standup’ moved to Aug 31, 2025 at 10:00 AM.
//
//» help me plan my week
//  intent=plan_week title=nil when=nil
//  → Here’s your plan for Aug 31–Sep 6: • 2 events
//

//4) Notes & options
//
//Model location
//
//App bundle: Bundle.main.url(forResource:"ZunloIntents", withExtension:"mlmodelc")
//
//SPM resource: add .process("Resources") in Package.swift, then inside the package you can use Bundle.module.url(...) and expose a helper (e.g., IntentEngine.bundled()).
//
//Defaults
//
//Event duration defaults to 30 min if no end time was parsed.
//
//Planning:
//
//plan_day → today’s range
//
//plan_week → current week range
//
//Rescheduling target
//
//Uses the scoring/ranking helper over EventLike to pick the best match from the candidate day, widening the window if needed.
//
//Next improvements
//
//Add your real repos (replace in-memory stores).
//
//Feed more training data for weaker intents, as you collect real Zunlo traffic.
//
//Extend recurrence parsing (e.g., “every weekday at 9:30”) and pass a proper recurrence rule to your event store.
