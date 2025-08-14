//
//  UserTask.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI
import RealmSwift

enum UserTaskPriority: Int, CaseIterable, Codable, CustomStringConvertible {
    case low, medium, high
    
    var color: Color {
        switch self {
        case .high: return .red.opacity(0.3)
        case .medium: return .orange.opacity(0.3)
        case .low: return .blue.opacity(0.3)
        }
    }
    
    var description: String {
        switch self {
        case .high: return String(localized: "high")
        case .medium: return String(localized: "medium")
        case .low: return String(localized: "low")
        }
    }
    
    var weight: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}

struct UserTask: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let userId: UUID?
    var title: String
    var notes: String?
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var priority: UserTaskPriority
    var parentEventId: UUID?
    var tags: [Tag]
    var reminderTriggers: [ReminderTrigger]?
    
    // NEW for sync v1
    var deletedAt: Date? = nil
    var needsSync: Bool = false

    var isActionable: Bool {
        !isCompleted && parentEventId == nil
    }
    
    init(
        id: UUID,
        userId: UUID? = nil,
        title: String,
        notes: String? = nil,
        isCompleted: Bool,
        createdAt: Date,
        updatedAt: Date,
        dueDate: Date? = nil,
        priority: UserTaskPriority,
        parentEventId: UUID? = nil,
        tags: [Tag],
        reminderTriggers: [ReminderTrigger]?,
        deletedAt: Date? = nil,
        needsSync: Bool = false
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
    }
}

extension UserTask: SchedulableReminderItem {
    var dueDateForReminder: Date? { dueDate }
}

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
    }
}

extension UserTask {
    init(remote: UserTaskRemote) {
        self.id = remote.id
        self.userId = remote.userId
        self.title = remote.title
        self.notes = remote.notes
        self.isCompleted = remote.isCompleted
        self.createdAt = remote.createdAt ?? Date()
        self.updatedAt = remote.updatedAt
        self.dueDate = remote.dueDate
        self.priority = remote.priority
        self.parentEventId = remote.parentEventId
        self.tags = Tag.toTag(tags: remote.tags)
        self.reminderTriggers = []
        self.deletedAt = remote.deletedAt
        self.needsSync = false
    }
}
