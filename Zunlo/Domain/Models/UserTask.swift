//
//  UserTask.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI
import RealmSwift
import SmartParseKit

public enum UserTaskPriority: Int, CaseIterable, Codable, CustomStringConvertible {
    case low = 0, medium = 1, high = 2
    
    public var color: Color {
        switch self {
        case .high: return .red.opacity(0.3)
        case .medium: return .orange.opacity(0.3)
        case .low: return .blue.opacity(0.3)
        }
    }
    
    // UI-only (localized). Don't use for API encoding.
    public var description: String {
        switch self {
        case .high:   return String(localized: "high")
        case .medium: return String(localized: "medium")
        case .low:    return String(localized: "low")
        }
    }
    
    // Stable API string
    private var apiString: String {
        switch self {
        case .low:    return "low"
        case .medium: return "medium"
        case .high:   return "high"
        }
    }
    
    public var weight: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
    
    public static func fromParseResult(priority: TaskPriority) -> UserTaskPriority {
        switch priority {
        case .low: return UserTaskPriority.low
        case .medium: return UserTaskPriority.medium
        case .high: return UserTaskPriority.high
        case .urgent: return UserTaskPriority.high
        }
    }
    
    // Strategy knob you can set on JSONEncoder.userInfo
    public enum Encoding: Sendable { case int, string }

    // Decode from either "low"/"medium"/"high" or 0/1/2
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try Int first (backward compatibility)
        if let intVal = try? container.decode(Int.self), let v = UserTaskPriority(rawValue: intVal) {
            self = v
            return
        }
        
        // Then String
        if let strVal = try? container.decode(String.self) {
            switch strVal.lowercased() {
            case "low":    self = .low
            case "medium", "med": self = .medium
            case "high":   self = .high
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid priority '\(strVal)'"
                )
            }
            return
        }
        
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected String or Int for priority"
        )
    }
    
    // Encode as int or string depending on encoder.userInfo
    public func encode(to encoder: Encoder) throws {
        let strategy = (encoder.userInfo[.priorityEncodingStrategy] as? Encoding) ?? .int
        var c = encoder.singleValueContainer()
        switch strategy {
        case .int:    try c.encode(rawValue)
        case .string: try c.encode(apiString)
        }
    }
}

public extension CodingUserInfoKey {
    static let priorityEncodingStrategy = CodingUserInfoKey(rawValue: "priorityEncodingStrategy")!
}

public struct UserTask: Identifiable, Codable, Hashable {
    public var id: UUID
    public var userId: UUID
    public var title: String
    public var notes: String?
    public var isCompleted: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var dueDate: Date?
    public var priority: UserTaskPriority
    public var parentEventId: UUID?
    public var tags: [Tag]
    public var reminderTriggers: [ReminderTrigger]?
    public var deletedAt: Date? = nil
    public var needsSync: Bool = false
    public var version: Int?

    public var isActionable: Bool {
        !isCompleted && parentEventId == nil
    }
    
    init(
        id: UUID,
        userId: UUID,
        title: String,
        notes: String? = nil,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        dueDate: Date? = nil,
        priority: UserTaskPriority = .medium,
        parentEventId: UUID? = nil,
        tags: [Tag] = [],
        reminderTriggers: [ReminderTrigger]? = [],
        deletedAt: Date? = nil,
        needsSync: Bool = false,
        version: Int? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dueDate = dueDate
        self.priority = priority
        self.parentEventId = parentEventId
        self.tags = tags
        self.reminderTriggers = reminderTriggers
        self.deletedAt = deletedAt
        self.needsSync = needsSync
        self.version = version
    }
}

extension UserTask: SchedulableReminderItem {
    var bodyDescription: String? {
        return dueDate?.formattedDate(dateFormat: .time,
                                      calendar: Calendar.appDefault,
                                      timeZone: Calendar.appDefault.timeZone)
    }
    
    var dueDateForReminder: Date? { dueDate }
}

extension UserTask: TaskType {}

extension UserTask {
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
        self.tags = Tag.toTag(tags: local.tagsArray)
        self.reminderTriggers = local.reminderTriggersArray
        self.deletedAt = local.deletedAt
        self.needsSync = local.needsSync
        self.version = local.version
    }
    
    init(remote: UserTaskRemote) {
        self.id = remote.id
        self.userId = remote.userId
        self.title = remote.title
        self.notes = remote.notes
        self.isCompleted = remote.isCompleted
        self.createdAt = remote.createdAt
        self.updatedAt = remote.updatedAt
        self.dueDate = remote.dueDate
        self.priority = remote.priority
        self.parentEventId = remote.parentEventId
        self.tags = Tag.toTag(tags: remote.tags)
        self.reminderTriggers = []
        self.deletedAt = remote.deletedAt
        self.needsSync = false
        self.version = remote.version
    }
}

extension UserTask {
    init(input: TaskCreateInput, userId: UUID) {
        self.id = UUID()
        self.userId = userId
        self.title = input.title
        self.notes = input.notes
        self.isCompleted = input.isCompleted
        self.createdAt = Date()
        self.updatedAt = Date()
        self.dueDate = input.dueDate
        self.priority = input.priority
        self.parentEventId = input.parentEventId
        self.tags = Tag.toTag(tags: input.tags)
        self.reminderTriggers = input.reminderTriggers
        self.deletedAt = nil
        self.needsSync = true
        self.version = nil
    }
    
    init(input: TaskPatchInput, userId: UUID) {
        self.id = UUID()
        self.userId = userId
        self.title = input.title.value ?? ""
        self.notes = input.notes.value
        self.isCompleted = input.isCompleted.value ?? false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.dueDate = input.dueDate.value
        self.priority = input.priority.value ?? .medium
        self.parentEventId = input.parentEventId.value
        self.tags = Tag.toTag(tags: input.tags.value ?? [])
        self.reminderTriggers = input.reminderTriggers.value
        self.deletedAt = nil
        self.needsSync = true
        self.version = nil
    }
}
