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
        case .high: return "high"
        case .medium: return "medium"
        case .low: return "low"
        }
    }
}

struct UserTask: Identifiable, Codable, Hashable {
    let id: UUID?
    let userId: UUID?
    var title: String
    var notes: String?
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var priority: UserTaskPriority
    var parentEventId: UUID?
    var tags: [String]
    var reminderTriggers: [ReminderTrigger]?
    
    internal init(id: UUID?,
                  userId: UUID? = nil,
                  title: String,
                  notes: String? = nil,
                  isCompleted: Bool,
                  createdAt: Date,
                  updatedAt: Date,
                  dueDate: Date? = nil,
                  priority: UserTaskPriority,
                  parentEventId: UUID? = nil,
                  tags: [String],
                  reminderTriggers: [ReminderTrigger]?) {
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
        self.tags = local.tagsArray
        self.reminderTriggers = local.reminderTriggersArray
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
        self.tags = remote.tags
        self.reminderTriggers = []
    }
}
