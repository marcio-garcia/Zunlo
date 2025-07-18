//
//  UserTaskRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation

struct UserTaskRemote: Codable, Identifiable {
    var id: UUID?
    var user_id: UUID?
    var title: String
    var notes: String?
    var is_completed: Bool
    var created_at: Date?
    var updated_at: Date
    var scheduled_date: Date?
    var due_date: Date?
    var priority: UserTaskPriority?
    var parent_event_id: UUID?
    var tags: [String]
    var reminder_triggers: [ReminderTrigger]?

    init(domain: UserTask) {
        self.id = domain.id
        self.user_id = domain.userId
        self.title = domain.title
        self.notes = domain.notes
        self.is_completed = domain.isCompleted
        self.created_at = domain.createdAt
        self.updated_at = domain.updatedAt
        self.scheduled_date = domain.scheduledDate
        self.due_date = domain.dueDate
        self.priority = domain.priority
        self.parent_event_id = domain.parentEventId
        self.tags = domain.tags
        self.reminder_triggers = domain.reminderTriggers
    }

    func toDomain() -> UserTask {
        UserTask(
            id: id ?? UUID(),
            userId: user_id,
            title: title,
            notes: notes,
            isCompleted: is_completed,
            createdAt: created_at ?? Date(),
            updatedAt: updated_at,
            scheduledDate: scheduled_date,
            dueDate: due_date,
            priority: priority,
            parentEventId: parent_event_id,
            tags: tags,
            reminderTriggers: reminder_triggers
        )
    }
}
