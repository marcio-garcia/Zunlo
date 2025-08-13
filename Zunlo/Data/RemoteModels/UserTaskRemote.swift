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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeSafely(UUID.self, forKey: .id)
        self.userId = try container.decodeSafely(UUID.self, forKey: .userId)
        self.title = try container.decodeSafely(String.self, forKey: .title)
        self.notes = try? container.decodeSafely(String.self, forKey: .notes)
        self.isCompleted = try container.decodeSafely(Bool.self, forKey: .isCompleted)
        self.priority = try container.decodeSafely(UserTaskPriority.self, forKey: .priority)
        self.parentEventId = try? container.decodeSafely(UUID.self, forKey: .parentEventId)
        self.tags = try container.decodeSafely([String].self, forKey: .tags)
        self.reminderTriggers = try? container.decodeSafely([ReminderTrigger].self, forKey: .reminderTriggers)
        
        let dueDate = try? container.decodeSafely(String.self, forKey: .dueDate)
        let createdAt = try? container.decodeSafely(String.self, forKey: .createdAt)
        let updatedAt = try container.decodeSafely(String.self, forKey: .updatedAt)
        
        self.updatedAt = DateFormatter.iso8601WithoutFractionalSeconds.date(from: updatedAt) ?? Date()
        
        self.dueDate = nil
        if let date = dueDate {
            self.dueDate = DateFormatter.iso8601WithoutFractionalSeconds.date(from: date)
        }
        
        self.createdAt = nil
        if let date = createdAt {
            self.createdAt = DateFormatter.iso8601WithFractionalSeconds.date(from: date)
        }
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
    }

//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        
//        try container.encode(title, forKey: .title)
//        try container.encode(isCompleted, forKey: .isCompleted)
//        try container.encode(updatedAt, forKey: .updatedAt)
//        try container.encode(priority, forKey: .priority)
//        try container.encode(tags, forKey: .tags)
//
//        if let id = self.id {
//            try container.encode(id, forKey: .id)
//        }
//        if let userId = self.userId {
//            try container.encode(userId, forKey: .userId)
//        }
//        if let createdAt = self.createdAt {
//            try container.encode(createdAt, forKey: .createdAt)
//        }
//        if let reminderTriggers = self.reminderTriggers {
//            try container.encode(reminderTriggers, forKey: .reminderTriggers)
//        }
//        
//        if let notes = self.notes {
//            try container.encode(notes, forKey: .notes)
//        } else {
//            try container.encodeNil(forKey: .notes)
//        }
//        
//        if let dueDate = self.dueDate {
//            try container.encode(dueDate, forKey: .dueDate)
//        } else {
//            try container.encodeNil(forKey: .dueDate)
//        }
//        
//        if let parentEventId = self.parentEventId {
//            try container.encode(parentEventId, forKey: .parentEventId)
//        } else {
//            try container.encodeNil(forKey: .parentEventId)
//        }
//    }
    
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
            reminderTriggers: reminderTriggers
        )
    }
}
