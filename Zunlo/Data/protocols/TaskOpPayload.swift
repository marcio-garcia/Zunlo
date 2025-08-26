//
//  TaskOpPayload.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/26/25.
//

import Foundation

// MARK: - Task payloads (server owns created_at/updated_at)
public struct TaskInsertPayload: Encodable {
    let id: UUID
    let user_id: UUID
    let title: String
    let notes: String?
    let is_completed: Bool
    let due_date: String?
    let priority: UserTaskPriority
    let parent_event_id: UUID?
    let tags: [String]
    let reminder_triggers: [ReminderTrigger]?
    let deleted_at: String?

    init(remote r: UserTaskRemote) {
        id = r.id
        user_id = r.userId
        title = r.title
        notes = r.notes
        is_completed = r.isCompleted
        due_date = r.dueDate.map(RFC3339MicrosUTC.string)
        priority = r.priority
        parent_event_id = r.parentEventId
        tags = r.tags
        reminder_triggers = r.reminderTriggers
        deleted_at = r.deletedAt.map(RFC3339MicrosUTC.string)
    }
}

public struct TaskUpdatePayload: Encodable {
    // PATCH-style optionals (send all for now = minimal change; you can sparsify later)
    let title: String?
    let notes: String?
    let is_completed: Bool?
    let due_date: String?
    let priority: UserTaskPriority?
    let parent_event_id: UUID?
    let tags: [String]?
    let reminder_triggers: [ReminderTrigger]?
    let deleted_at: String?

    static func full(from r: UserTaskRemote) -> TaskUpdatePayload {
        .init(
            title: r.title,
            notes: r.notes,
            is_completed: r.isCompleted,
            due_date: r.dueDate.map(RFC3339MicrosUTC.string),
            priority: r.priority,
            parent_event_id: r.parentEventId,
            tags: r.tags,
            reminder_triggers: r.reminderTriggers,
            deleted_at: r.deletedAt.map(RFC3339MicrosUTC.string)
        )
    }
}
