//
//  UserTaskRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation

public struct UserTaskRemote: RemoteEntity, Codable, Identifiable {
    public var id: UUID
    public var userId: UUID
    public var title: String
    public var notes: String?
    public var isCompleted: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedAtRaw: String?
    public var dueDate: Date?
    public var priority: UserTaskPriority
    public var parentEventId: UUID?
    public var tags: [String]
    public var reminderTriggers: [ReminderTrigger]?
    public var deletedAt: Date?
    public var version: Int?
    
    init(
        id: UUID,
        userId: UUID,
        title: String,
        notes: String? = nil,
        isCompleted: Bool,
        createdAt: Date,
        updatedAt: Date,
        updatedAtRaw: String? = nil,
        dueDate: Date? = nil,
        priority: UserTaskPriority,
        parentEventId: UUID? = nil,
        tags: [String],
        reminderTriggers: [ReminderTrigger]? = nil,
        deletedAt: Date? = nil,
        version: Int? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.updatedAtRaw = updatedAtRaw
        self.dueDate = dueDate
        self.priority = priority
        self.parentEventId = parentEventId
        self.tags = tags
        self.reminderTriggers = reminderTriggers
        self.deletedAt = deletedAt
        self.version = version
    }
}

extension UserTaskRemote {
    init(domain: UserTask) {
        self.id = domain.id
        self.userId = domain.userId
        self.title = domain.title
        self.notes = domain.notes
        self.isCompleted = domain.isCompleted
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
        self.dueDate = domain.dueDate
        self.priority = domain.priority
        self.parentEventId = domain.parentEventId
        self.tags = domain.tags.map({ $0.text })
        self.reminderTriggers = domain.reminderTriggers
        self.deletedAt = domain.deletedAt
        self.version = domain.version
        self.updatedAtRaw = ""
    }
    
    init(local: UserTaskLocal) {
        self.id = local.id
        self.userId = local.userId
        self.title = local.title
        self.notes = local.notes
        self.isCompleted = local.isCompleted
        self.createdAt = local.createdAt
        self.updatedAt = local.updatedAt
        self.dueDate = local.dueDate
        self.priority = local.priority.toDomain()
        self.parentEventId = local.parentEventId
        self.tags = local.tagsArray
        self.reminderTriggers = local.reminderTriggersArray
        self.deletedAt = local.deletedAt
        self.version = local.version
        self.updatedAtRaw = ""
    }
    
    func toDomain() -> UserTask {
        UserTask(
            id: id,
            userId: userId,
            title: title,
            notes: notes,
            isCompleted: isCompleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            dueDate: dueDate,
            priority: priority,
            parentEventId: parentEventId,
            tags: tags.map({
                Tag(id: UUID(),
                    text: $0,
                    color: "",
                    selected: false)
            }),
            reminderTriggers: reminderTriggers,
            deletedAt: deletedAt,
            needsSync: false,
            version: version
        )
    }
}

extension UserTaskRemote {
    var isInsertCandidate: Bool { version == nil }
}

extension UserTaskRemote {
    enum CodingKeys: String, CodingKey {
        case id
        case userId            = "user_id"
        case title
        case notes
        case isCompleted       = "is_completed"
        case createdAt         = "created_at"   // REQUIRED from server; we DO NOT encode it
        case updatedAt         = "updated_at"   // REQUIRED
        case dueDate           = "due_date"
        case priority
        case parentEventId     = "parent_event_id"
        case tags
        case reminderTriggers  = "reminder_triggers"
        case deletedAt         = "deleted_at"
        case version
    }
}

// MARK: - Telemetry hook + migration toggle
private enum _DecodePolicy {
    /// Turn on temporarily during migration to allow fallback for invalid created_at.
    static var allowCreatedAtFallbackDuringMigration: Bool { false }

    static func reportDecodeIssue(entity: String, id: UUID?, field: String, raw: String) {
        // Replace with your logger/telemetry sink
        print("[DECODE] \(entity)#\(id?.uuidString ?? "?").\(field) invalid: \(raw)")
    }
}

extension UserTaskRemote {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
        priority = try c.decode(UserTaskPriority.self, forKey: .priority)
        parentEventId = try c.decodeIfPresent(UUID.self, forKey: .parentEventId)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        reminderTriggers = try c.decodeIfPresent([ReminderTrigger].self, forKey: .reminderTriggers)
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

        if let dueRaw = try c.decodeIfPresent(String.self, forKey: .dueDate) {
            guard let d = RFC3339MicrosUTC.parse(dueRaw) else {
                _DecodePolicy.reportDecodeIssue(entity: "UserTaskRemote", id: id, field: "due_date", raw: dueRaw)
                throw DecodingError.dataCorruptedError(forKey: .dueDate, in: c, debugDescription: "Invalid due_date: \(dueRaw)")
            }
            dueDate = d
        } else {
            dueDate = nil
        }

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
        var c = encoder.container(keyedBy: CodingKeys.self)

        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(userId, forKey: .userId)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encode(isCompleted, forKey: .isCompleted)

        // 🚫 Do NOT encode created_at nor updated_at — server owns it
        // try c.encode(RFC3339MicrosUTC.string(createdAt), forKey: .createdAt)
        // try c.encode(RFC3339MicrosUTC.string(updatedAt), forKey: .updatedAt)

        if let dueDate {
            try c.encode(RFC3339MicrosUTC.string(dueDate), forKey: .dueDate)
        }

        try c.encode(priority, forKey: .priority)
        try c.encodeIfPresent(parentEventId, forKey: .parentEventId)
        try c.encode(tags, forKey: .tags)
        try c.encodeIfPresent(reminderTriggers, forKey: .reminderTriggers)
        try c.encodeIfPresent(deletedAt.map(RFC3339MicrosUTC.string), forKey: .deletedAt)
        try c.encodeIfPresent(version, forKey: .version)
    }
}
