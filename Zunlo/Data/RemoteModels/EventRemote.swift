//
//  EventRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

// MARK: - Telemetry hook + migration toggle
public enum _DecodePolicy {
    /// Turn on temporarily during migration to allow fallback for invalid created_at.
    public static var allowCreatedAtFallbackDuringMigration: Bool { false }

    public static func reportDecodeIssue(entity: String, id: UUID?, field: String, raw: String) {
        // Replace with your logger/telemetry sink
        print("[DECODE] \(entity)#\(id?.uuidString ?? "?").\(field) invalid: \(raw)")
    }
}

extension EventRemote {
    var isInsertCandidate: Bool { version == nil }
}

public struct EventRemote: RemoteEntity, Codable, Identifiable {
    public var id: UUID
    public var user_id: UUID
    public var title: String
    public var notes: String?
    public var start_datetime: Date
    public var end_datetime: Date
    public var is_recurring: Bool
    public var location: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedAtRaw: String?
    public var color: EventColor?
    public var reminder_triggers: [ReminderTrigger]?
    public var deletedAt: Date?
    public var version: Int?
}

extension EventRemote {
    init(domain: Event) {
        self.id = domain.id
        self.user_id = domain.userId
        self.title = domain.title
        self.notes = domain.notes
        self.start_datetime = domain.startDate
        self.end_datetime = domain.endDate
        self.is_recurring = domain.isRecurring
        self.location = domain.location
        self.createdAt = domain.createdAt // ok to send or omit; server can default too
        self.updatedAt = domain.updatedAt // server trigger will bump anyway
        self.color = domain.color
        self.reminder_triggers = domain.reminderTriggers
        self.deletedAt = domain.deletedAt
        self.version = domain.version
    }
    
    init(local: EventLocal) {
        self.id = local.id
        self.user_id = local.userId
        self.title = local.title
        self.notes = local.notes
        self.start_datetime = local.startDate
        self.end_datetime = local.endDate
        self.is_recurring = local.isRecurring
        self.location = local.location
        self.createdAt = local.createdAt
        self.updatedAt = local.updatedAt
        self.color = local.color
        self.reminder_triggers = local.reminderTriggersArray
        self.deletedAt = local.deletedAt
        self.version = local.version
    }
}

extension EventRemote {
    init(input: EventCreateInput, userId: UUID) {
        self.id = UUID()
        self.user_id = userId
        self.title = input.title
        self.notes = input.notes
        self.start_datetime = input.startDatetime
        self.end_datetime = input.endDatetime ?? input.startDatetime
        self.is_recurring = false
        self.location = input.location
        self.createdAt = Date()
        self.updatedAt = Date()
        self.color = input.color ?? .softOrange
        self.reminder_triggers = input.reminderTriggers
        self.deletedAt = nil
        self.version = nil
    }
    
    init(input: EventPatchInput, userId: UUID) {
        self.id = UUID()
        self.user_id = userId
        self.title = input.title.value ?? "Update event"
        self.notes = input.notes.value
        self.start_datetime = input.startDatetime.value ?? Date()
        self.end_datetime = input.endDatetime.value ?? start_datetime
        self.is_recurring = false
        self.location = input.location.value
        self.createdAt = Date()
        self.updatedAt = Date()
        self.color = input.color.value ?? .softOrange
        self.reminder_triggers = input.reminderTriggers.value
        self.deletedAt = nil
        self.version = nil
    }
}
extension EventRemote {
    enum CodingKeys: String, CodingKey {
        case id
        case user_id            = "user_id"
        case title
        case notes
        case start_datetime     = "start_datetime"
        case end_datetime       = "end_datetime"
        case createdAt          = "created_at"   // REQUIRED from server; we DO NOT encode it
        case updatedAt          = "updated_at"   // REQUIRED
        case location
        case is_recurring       = "is_recurring"
        case color
        case reminder_triggers  = "reminder_triggers"
        case deletedAt          = "deleted_at"
        case version
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decode(UUID.self, forKey: .id)
        user_id = try c.decode(UUID.self, forKey: .user_id)
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        is_recurring = try c.decode(Bool.self, forKey: .is_recurring)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        color = try c.decodeIfPresent(EventColor.self, forKey: .color)
        reminder_triggers = try c.decodeIfPresent([ReminderTrigger].self, forKey: .reminder_triggers)
        version = try c.decodeIfPresent(Int.self, forKey: .version)

        // Decode updatedAt (required) first so we can use it as a fallback for createdAt during migration.
        let raw = try c.decode(String.self, forKey: .updatedAt)
        updatedAtRaw = raw
        guard let updatedAtParsed = RFC3339MicrosUTC.parse(raw) else {
            _DecodePolicy.reportDecodeIssue(entity: "UserTaskRemote", id: id, field: "updated_at", raw: raw)
            throw DecodingError.dataCorruptedError(forKey: .updatedAt, in: c, debugDescription: "Invalid updated_at: \(raw)")
        }
        updatedAt = updatedAtParsed

        // createdAt is REQUIRED (server wins entirely). Use tolerant parse; allow temporary fallback if enabled.
        let createdAtRaw = try c.decode(String.self, forKey: .createdAt)
        if let createdAtParsed = RFC3339MicrosUTC.parse(createdAtRaw) {
            createdAt = createdAtParsed
        } else if _DecodePolicy.allowCreatedAtFallbackDuringMigration {
            _DecodePolicy.reportDecodeIssue(entity: "UserTaskRemote", id: id, field: "created_at", raw: createdAtRaw)
            // Mitigation C: temporary unblock—use updatedAt. Remove once DB is clean.
            createdAt = updatedAt
        } else {
            _DecodePolicy.reportDecodeIssue(entity: "UserTaskRemote", id: id, field: "created_at", raw: createdAtRaw)
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: c, debugDescription: "Invalid created_at: \(createdAtRaw)")
        }

        let startDatetimeRaw = try c.decode(String.self, forKey: .start_datetime)
        guard let d = RFC3339MicrosUTC.parse(startDatetimeRaw) else {
            _DecodePolicy.reportDecodeIssue(entity: "UserTaskRemote", id: id, field: "due_date", raw: startDatetimeRaw)
            throw DecodingError.dataCorruptedError(forKey: .start_datetime, in: c, debugDescription: "Invalid due_date: \(startDatetimeRaw)")
        }
        start_datetime = d
        
        let endDatetimeRaw = try c.decode(String.self, forKey: .end_datetime)
        guard let d = RFC3339MicrosUTC.parse(endDatetimeRaw) else {
            _DecodePolicy.reportDecodeIssue(entity: "UserTaskRemote", id: id, field: "due_date", raw: endDatetimeRaw)
            throw DecodingError.dataCorruptedError(forKey: .end_datetime, in: c, debugDescription: "Invalid due_date: \(endDatetimeRaw)")
        }
        end_datetime = d
        
        if let delRaw = try c.decodeIfPresent(String.self, forKey: .deletedAt) {
            guard let d = RFC3339MicrosUTC.parse(delRaw) else {
                _DecodePolicy.reportDecodeIssue(entity: "UserTaskRemote", id: id, field: "deleted_at", raw: delRaw)
                throw DecodingError.dataCorruptedError(forKey: .deletedAt, in: c, debugDescription: "Invalid deleted_at: \(delRaw)")
            }
            deletedAt = d
        } else {
            deletedAt = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        let strategy = (encoder.userInfo[.serverOwnedEncodingStrategy] as? ServerOwnedEncoding) ?? .exclude
        var c = encoder.container(keyedBy: CodingKeys.self)

        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(user_id, forKey: .user_id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encode(is_recurring, forKey: .is_recurring)

        // Do NOT encode created_at nor updated_at
        // when sending to server — server owns it
        switch strategy {
        case .include:
            try c.encode(RFC3339MicrosUTC.string(updatedAt), forKey: .updatedAt)
            try c.encode(RFC3339MicrosUTC.string(createdAt), forKey: .createdAt)
        case .exclude:
            break
        }
        
        try c.encode(RFC3339MicrosUTC.string(start_datetime), forKey: .start_datetime)
        try c.encode(RFC3339MicrosUTC.string(end_datetime), forKey: .end_datetime)

        try c.encode(color, forKey: .color)
        try c.encodeIfPresent(location, forKey: .location)
        try c.encodeIfPresent(reminder_triggers, forKey: .reminder_triggers)
        try c.encodeIfPresent(deletedAt.map(RFC3339MicrosUTC.string), forKey: .deletedAt)
        try c.encodeIfPresent(version, forKey: .version)
    }
}
