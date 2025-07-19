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
    var due_date: Date?
    var priority: UserTaskPriority
    var parent_event_id: UUID?
    var tags: [String]
    var reminder_triggers: [ReminderTrigger]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case user_id = "user_id"
        case title
        case notes
        case is_completed = "is_completed"
        case created_at = "created_at"
        case updated_at = "updated_at"
        case due_date = "due_date"
        case priority
        case parent_event_id = "parent_event_id"
        case tags
        case reminder_triggers = "reminder_triggers"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeSafely(UUID.self, forKey: .id)
        self.user_id = try container.decodeSafely(UUID.self, forKey: .user_id)
        self.title = try container.decodeSafely(String.self, forKey: .title)
        self.notes = try? container.decodeSafely(String.self, forKey: .notes)
        self.is_completed = try container.decodeSafely(Bool.self, forKey: .is_completed)
        self.priority = try container.decodeSafely(UserTaskPriority.self, forKey: .priority)
        self.parent_event_id = try? container.decodeSafely(UUID.self, forKey: .parent_event_id)
        self.tags = try container.decodeSafely([String].self, forKey: .tags)
        self.reminder_triggers = try? container.decodeSafely([ReminderTrigger].self, forKey: .reminder_triggers)
        
        let due_date = try? container.decodeSafely(String.self, forKey: .due_date)
        let created_at = try? container.decodeSafely(String.self, forKey: .created_at)
        let updated_at = try container.decodeSafely(String.self, forKey: .updated_at)
        
        self.updated_at = DateFormatter.iso8601WithoutFractionalSeconds.date(from: updated_at) ?? Date()
        
        self.due_date = nil
        if let date = due_date {
            self.due_date = DateFormatter.iso8601WithoutFractionalSeconds.date(from: date)
        }
        
        self.created_at = nil
        if let date = created_at {
            self.created_at = DateFormatter.iso8601WithFractionalSeconds.date(from: date)
        }
    }
    
    init(domain: UserTask) {
        self.id = domain.id
        self.user_id = domain.userId
        self.title = domain.title
        self.notes = domain.notes
        self.is_completed = domain.isCompleted
        self.created_at = domain.createdAt
        self.updated_at = domain.updatedAt
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
            dueDate: due_date,
            priority: priority,
            parentEventId: parent_event_id,
            tags: tags,
            reminderTriggers: reminder_triggers
        )
    }
}
