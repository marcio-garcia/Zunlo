//
//  UserTask.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation
import RealmSwift

enum UserTaskPriority: String, CaseIterable, Codable {
    case low, medium, high
}

struct UserTask: Identifiable, Codable, Hashable {
    let id: UUID?
    let userId: UUID?
    var title: String
    var notes: String?
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date
    var scheduledDate: Date?
    var dueDate: Date?
    var priority: UserTaskPriority?
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
                  scheduledDate: Date? = nil,
                  dueDate: Date? = nil,
                  priority: UserTaskPriority? = nil,
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
        self.scheduledDate = scheduledDate
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
        self.scheduledDate = local.scheduledDate
        self.dueDate = local.dueDate
        self.priority = local.priority?.toDomain()
        self.parentEventId = local.parentEventId
        self.tags = local.tagsArray
        self.reminderTriggers = local.reminderTriggersArray
    }
}

extension UserTask {
    init(remote: UserTaskRemote) {
        self.id = remote.id
        self.userId = remote.user_id
        self.title = remote.title
        self.notes = remote.notes
        self.isCompleted = remote.is_completed
        self.createdAt = remote.created_at ?? Date()
        self.updatedAt = remote.updated_at
        self.scheduledDate = remote.scheduled_date
        self.dueDate = remote.due_date
        self.priority = remote.priority
        self.parentEventId = remote.parent_event_id
        self.tags = remote.tags
        self.reminderTriggers = []
    }
}
