//
//  UserTaskRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation

struct UserTaskRemote: Codable, Identifiable {
    var id: UUID
    var userId: UUID?
    var title: String
    var notes: String?
    var isCompleted: Bool
    var createdAt: Date?
    var updatedAt: Date
    var dueDate: Date?
    var priority: UserTaskPriority
    var parentEventId: UUID?
    var tags: [String]
    var reminderTriggers: [ReminderTrigger]?
    
    // NEW
    var deletedAt: Date? = nil       // maps to deleted_at
    var version: Int? = nil
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case notes
        case isCompleted = "is_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case dueDate = "due_date"
        case priority
        case parentEventId = "parent_event_id"
        case tags
        case reminderTriggers = "reminder_triggers"
        case deletedAt = "deleted_at"
        case version
    }
    
    init(
        id: UUID,
        userId: UUID? = nil,
        title: String,
        notes: String? = nil,
        isCompleted: Bool,
        createdAt: Date? = nil,
        updatedAt: Date,
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
        self.dueDate = dueDate
        self.priority = priority
        self.parentEventId = parentEventId
        self.tags = tags
        self.reminderTriggers = reminderTriggers
        self.deletedAt = deletedAt
        self.version = version
    }
    
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
        self.version = nil
    }
    
    func toDomain() -> UserTask {
        UserTask(
            id: id,
            userId: userId,
            title: title,
            notes: notes,
            isCompleted: isCompleted,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt,
            dueDate: dueDate,
            priority: priority,
            parentEventId: parentEventId,
            tags: tags.map({
                Tag(id: UUID(),
                    text: $0, color:
                        Theme.highlightColor(for: $0),
                    selected: false)
            }),
            reminderTriggers: reminderTriggers,
            deletedAt: deletedAt,
            needsSync: false
        )
    }
}
