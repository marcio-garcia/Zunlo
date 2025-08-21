//
//  AIToolModels.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation

public enum EditScope: String, Codable { case single, override, this_and_future, entire_series }

/// Used when we don't need to decode any response payload.
public struct EmptyResponse: Decodable {}

// Base envelope
public struct BaseMutationWire: Codable {
    public var intent: String                 // "create" | "update" | "delete"
    public var idempotencyKey: String         // UUID string
    public var reason: String
    public var dryRun: Bool?
}

// MARK: - Args decoded from tool calls (model-facing)
struct CreateTaskArgs: Decodable { var task: TaskCreateInput }
struct UpdateTaskArgs: Decodable { var taskId: UUID; var patch: TaskPatchInput }
struct DeleteTaskArgs: Decodable { var taskId: UUID }

struct CreateEventArgs: Decodable { var event: EventCreateInput }
struct UpdateEventArgs: Decodable {
    var eventId: UUID
    var editScope: EditScope
    var occurrenceDate: Date?
    var patch: EventPatchInput
}
struct DeleteEventArgs: Decodable {
    var eventId: UUID
    var editScope: EditScope
    var occurrenceDate: Date?
}

// MARK: Args decoded for readonly tools
public struct GetAgendaArgs: Codable {
    public enum DateRange: String, Codable { case today, tomorrow, week, custom }
    public let dateRange: DateRange
    public let start: Date?
    public let end: Date?
    // Optionally add: public let timezone: String?
}
public struct PlanWeekArgs: Codable {
    public let startDate: Date // YYYY-MM-DD from tool (decode with .iso8601 + dateOnly ok)
    public let objectives: [String]?
    public let constraints: [String: String]? // keep loose; you can structure later
    public let horizon: String? // "day" | "week" (default "week")
}


/// Tri-state field for PATCH:
/// - .omit      -> do not include the key
/// - .set(val)  -> include key with value
/// - .null      -> include key with JSON null (explicit clear)
enum Field<T: Codable>: Codable {
    case omit
    case set(T)
    case null

    // ENCODE
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .omit: break // caller decides whether to write the key
        case .set(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    // DECODE (used only when the key is present)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else {
            let v = try c.decode(T.self)
            self = .set(v)
        }
    }
}

struct PatchEncoder {
    static func encode<K: CodingKey, T: Codable>(_ f: Field<T>, into c: inout KeyedEncodingContainer<K>, key: K) throws {
        switch f {
        case .omit: break
        case .set(let v): try c.encode(v, forKey: key)
        case .null: try c.encodeNil(forKey: key)
        }
    }
}


// CREATE
struct TaskCreateInput: Codable {
    var title: String
    var notes: String?
    var dueDate: Date?
    var isCompleted: Bool?
    var tags: [String]?
    var reminderTriggers: [ReminderTrigger]?
    var parentEventId: UUID?
    var priority: UserTaskPriority?
}

struct EventCreateInput: Codable {
    var title: String
    var startDatetime: Date
    var endDatetime: Date?
    var notes: String?
    var location: String?
    var color: EventColor?
    var reminderTriggers: [ReminderTrigger]?
    var recurrenceRule: RecurrenceRule?   // your Apple 1–7 weekdays
}

// PATCH (uses Field<> for tri-state)
struct TaskPatchInput: Codable {
    var title: Field<String> = .omit
    var notes: Field<String> = .omit
    var dueDate: Field<Date> = .omit
    var isCompleted: Field<Bool> = .omit
    var tags: Field<[String]> = .omit
    var reminderTriggers: Field<[ReminderTrigger]> = .omit
    var parentEventId: Field<UUID> = .omit
    var priority: Field<UserTaskPriority> = .omit

    private enum CodingKeys: String, CodingKey {
        case title, notes, dueDate, isCompleted, tags, reminderTriggers, parentEventId, priority
    }

    // ENCODE only writes keys that are not .omit
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try PatchEncoder.encode(title,            into: &c, key: .title)
        try PatchEncoder.encode(notes,            into: &c, key: .notes)
        try PatchEncoder.encode(dueDate,          into: &c, key: .dueDate)
        try PatchEncoder.encode(isCompleted,      into: &c, key: .isCompleted)
        try PatchEncoder.encode(tags,             into: &c, key: .tags)
        try PatchEncoder.encode(reminderTriggers, into: &c, key: .reminderTriggers)
        try PatchEncoder.encode(parentEventId,    into: &c, key: .parentEventId)
        try PatchEncoder.encode(priority,         into: &c, key: .priority)
    }

    // DECODE sets .omit when the key is missing; .set/.null when present
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func decodeField<T: Codable>(_ key: CodingKeys, _ type: T.Type) -> Field<T> {
            (try? c.decodeIfPresent(Field<T>.self, forKey: key)) ?? .omit
        }
        title            = decodeField(.title, String.self)
        notes            = decodeField(.notes, String.self)
        dueDate          = decodeField(.dueDate, Date.self)
        isCompleted      = decodeField(.isCompleted, Bool.self)
        tags             = decodeField(.tags, [String].self)
        reminderTriggers = decodeField(.reminderTriggers, [ReminderTrigger].self)
        parentEventId    = decodeField(.parentEventId, UUID.self)
        priority         = decodeField(.priority, UserTaskPriority.self)
    }

    // Keep the default memberwise init for building patches locally.
}

struct EventPatchInput: Codable {
    var title: Field<String> = .omit
    var startDatetime: Field<Date> = .omit
    var endDatetime: Field<Date> = .omit         // .null clears end
    var notes: Field<String> = .omit
    var location: Field<String> = .omit
    var color: Field<EventColor> = .omit
    var reminderTriggers: Field<[ReminderTrigger]> = .omit
    var recurrenceRule: Field<RecurrenceRule?> = .omit // .set(nil) removes recurrence

    private enum CodingKeys: String, CodingKey {
        case title, startDatetime, endDatetime, notes, location, color, reminderTriggers, recurrenceRule
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try PatchEncoder.encode(title,            into: &c, key: .title)
        try PatchEncoder.encode(startDatetime,    into: &c, key: .startDatetime)
        try PatchEncoder.encode(endDatetime,      into: &c, key: .endDatetime)
        try PatchEncoder.encode(notes,            into: &c, key: .notes)
        try PatchEncoder.encode(location,         into: &c, key: .location)
        try PatchEncoder.encode(color,            into: &c, key: .color)
        try PatchEncoder.encode(reminderTriggers, into: &c, key: .reminderTriggers)
        try PatchEncoder.encode(recurrenceRule,   into: &c, key: .recurrenceRule)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func decodeField<T: Codable>(_ key: CodingKeys, _ type: T.Type) -> Field<T> {
            (try? c.decodeIfPresent(Field<T>.self, forKey: key)) ?? .omit
        }
        title            = decodeField(.title, String.self)
        startDatetime    = decodeField(.startDatetime, Date.self)
        endDatetime      = decodeField(.endDatetime, Date.self)
        notes            = decodeField(.notes, String.self)
        location         = decodeField(.location, String.self)
        color            = decodeField(.color, EventColor.self)
        reminderTriggers = decodeField(.reminderTriggers, [ReminderTrigger].self)
        // special-case optional RecurrenceRule?:
        if c.contains(.recurrenceRule) {
            if try c.decodeNil(forKey: .recurrenceRule) { recurrenceRule = .null }
            else {
                let val = try c.decode(RecurrenceRule.self, forKey: .recurrenceRule)
                recurrenceRule = .set(val)
            }
        } else {
            recurrenceRule = .omit
        }
    }
}


public struct CreateTaskPayloadWire: Encodable {
    var intent: String = "create"
    var idempotencyKey: String
    var reason: String
    var dryRun: Bool?
    var task: TaskCreateInput
}

public struct UpdateTaskPayloadWire: Encodable {
    var intent: String = "update"
    var idempotencyKey: String
    var reason: String
    var dryRun: Bool?
    var taskId: UUID
    var version: Int
    var patch: TaskPatchInput
}

public struct DeleteTaskPayloadWire: Encodable {
    public var intent: String = "delete"
    public var idempotencyKey: String
    public var reason: String
    public var dryRun: Bool?
    public var taskId: UUID
    public var version: Int
}

public struct CreateEventPayloadWire: Encodable {
    var intent: String = "create"
    var idempotencyKey: String
    var reason: String
    var dryRun: Bool?
    var event: EventCreateInput
}

public struct UpdateEventPayloadWire: Encodable {
    var intent: String = "update"
    var idempotencyKey: String
    var reason: String
    var dryRun: Bool?
    var eventId: UUID
    var version: Int
    var editScope: EditScope
    var occurrenceDate: Date?
    var patch: EventPatchInput
}

public struct DeleteEventPayloadWire: Encodable {
    public var intent: String = "delete"
    public var idempotencyKey: String
    public var reason: String
    public var dryRun: Bool?
    public var eventId: UUID
    public var version: Int
    public var editScope: EditScope
    public var occurrenceDate: Date?
}
// --- Server responses (authoritative snapshots for immediate local apply)

public struct TaskMutationResult: Codable {
    var ok: Bool
    var task: UserTaskRemote?
    var code: String?
    var message: String?
}

public struct EventMutationResult: Codable {
    var ok: Bool
    var event: EventRemote?
    var recurrenceRule: RecurrenceRuleRemote?
    var override: EventOverrideRemote?
    var code: String?
    var message: String?
}

// ---- GetAgenda tool

public struct AgendaEvent: Codable {
    var kind: String = "event"
    var id: UUID
    var title: String
    var start: Date
    var end: Date?
    var location: String?
    var color: String?
    var isOverride: Bool
    var isRecurring: Bool
}

public struct AgendaTask: Codable {
    var kind: String = "task"
    var id: UUID
    var title: String
    var dueDate: Date?
    var priority: String  // "low"|"medium"|"high"
    var tags: [String]
}

public struct GetAgendaResult: Codable {
    var start: Date
    var end: Date
    var timezone: String
    var items: [AgendaItem] // enum wrapper over event/task
}

public enum AgendaItem: Codable {
    case event(AgendaEvent)
    case task(AgendaTask)
}

// Output

struct ProposedBlock: Codable {
    enum Kind: String, Codable { case meeting, focus, buffer }
    let kind: Kind
    let start: Date
    let end: Date?
    let title: String
    let taskId: UUID?
    let eventId: UUID?
}
public struct ProposedPlan: Codable {
    let start: Date
    let end: Date
    let blocks: [ProposedBlock]
    let notes: [String]
}

// Tool call models

public enum ToolCallOrigin: Codable, Equatable, Sendable {
    case requiredAction   // came from `response.required_action`
    case streamed         // came from `response.function_call_*` events
}

public struct ToolCallRequest: Codable, Hashable, Sendable {
    public let id: String          // tool_call_id from OpenAI
    public let name: String
    public let argumentsJSON: String
    public let responseId: String  // OpenAI response.id so we know where to submit
    public let origin: ToolCallOrigin
}

public struct ToolOutput: Encodable {
    public let tool_call_id: String
    public let output: String   // must be a string; JSON → stringify first
}
