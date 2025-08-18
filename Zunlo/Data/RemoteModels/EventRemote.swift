//
//  EventRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

struct EventRemote: Codable, Identifiable {
    var id: UUID
    var user_id: UUID?
    var title: String
    var notes: String?
    var start_datetime: Date
    var end_datetime: Date?
    var is_recurring: Bool
    var location: String?
    var created_at: Date?
    var updated_at: Date
    var color: EventColor?
    var reminder_triggers: [ReminderTrigger]?
    var deleted_at: Date?
    var version: Int?
    
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        self.id = try container.decodeSafely(UUID.self, forKey: .id)
//        self.user_id = try container.decodeSafely(UUID.self, forKey: .user_id)
//        self.title = try container.decodeSafely(String.self, forKey: .title)
//        self.description = try? container.decodeSafely(String.self, forKey: .description)
//        self.is_recurring = try container.decodeSafely(Bool.self, forKey: .is_recurring)
//        self.location = try? container.decodeSafely(String.self, forKey: .location)
//        self.color = try? container.decodeSafely(EventColor.self, forKey: .color)
//        self.reminder_triggers = try? container.decode([ReminderTrigger].self, forKey: .reminder_triggers)
//        
//        let start_datetime = try container.decode(String.self, forKey: .start_datetime)
//        let end_datetime = try? container.decodeSafely(String.self, forKey: .end_datetime)
//        let created_at = try? container.decodeSafely(String.self, forKey: .created_at)
//        let updated_at = try container.decodeSafely(String.self, forKey: .updated_at)
//        
//        self.start_datetime = DateFormatter.iso8601WithoutFractionalSeconds.date(from: start_datetime) ?? Date()
//        self.updated_at = DateFormatter.iso8601WithoutFractionalSeconds.date(from: updated_at) ?? Date()
//        
//        self.end_datetime = nil
//        if let date = end_datetime {
//            self.end_datetime = DateFormatter.iso8601WithoutFractionalSeconds.date(from: date)
//        }
//        
//        self.created_at = nil
//        if let date = created_at {
//            self.created_at = DateFormatter.iso8601WithFractionalSeconds.date(from: date)
//        }
//        
//    }
}

extension EventRemote {
    init(domain: Event) {
        self.id = domain.id
        self.user_id = nil // omit so DEFAULT auth.uid() applies on insert
        self.title = domain.title
        self.notes = domain.notes
        self.start_datetime = domain.startDate
        self.end_datetime = domain.endDate
        self.is_recurring = domain.isRecurring
        self.location = domain.location
        self.created_at = domain.createdAt // ok to send or omit; server can default too
        self.updated_at = domain.updatedAt // server trigger will bump anyway
        self.color = domain.color
        self.reminder_triggers = domain.reminderTriggers
        
        self.deleted_at = domain.deletedAt
        self.version = nil // reserved for v2
    }
    
    init(local: EventLocal) {
        self.id = local.id
        self.user_id = nil // omit so DEFAULT auth.uid() applies on insert
        self.title = local.title
        self.notes = local.notes
        self.start_datetime = local.startDate
        self.end_datetime = local.endDate
        self.is_recurring = local.isRecurring
        self.location = local.location
        self.created_at = local.createdAt
        self.updated_at = local.updatedAt
        self.color = local.color
        self.reminder_triggers = local.reminderTriggersArray
        
        self.deleted_at = local.deletedAt
        self.version = nil
    }
}
