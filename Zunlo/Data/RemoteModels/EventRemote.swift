//
//  EventRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

struct EventRemote: Codable, Identifiable {
    var id: UUID?
    var user_id: UUID?
    let title: String
    let description: String?
    let start_datetime: Date
    var end_datetime: Date?
    let is_recurring: Bool
    let location: String?
    var created_at: Date?
    let updated_at: Date
    let color: EventColor?
    let reminder_triggers: [ReminderTrigger]?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeSafely(UUID.self, forKey: .id)
        self.user_id = try container.decodeSafely(UUID.self, forKey: .user_id)
        self.title = try container.decodeSafely(String.self, forKey: .title)
        self.description = try? container.decodeSafely(String.self, forKey: .description)
        self.is_recurring = try container.decodeSafely(Bool.self, forKey: .is_recurring)
        self.location = try? container.decodeSafely(String.self, forKey: .location)
        self.color = try? container.decodeSafely(EventColor.self, forKey: .color)
        self.reminder_triggers = try? container.decode([ReminderTrigger].self, forKey: .reminder_triggers)
        
        let start_datetime = try container.decode(String.self, forKey: .start_datetime)
        let end_datetime = try? container.decodeSafely(String.self, forKey: .end_datetime)
        let created_at = try? container.decodeSafely(String.self, forKey: .created_at)
        let updated_at = try container.decodeSafely(String.self, forKey: .updated_at)
        
        self.start_datetime = DateFormatter.iso8601WithoutFractionalSeconds.date(from: start_datetime) ?? Date()
        self.updated_at = DateFormatter.iso8601WithoutFractionalSeconds.date(from: updated_at) ?? Date()
        
        self.end_datetime = nil
        if let date = end_datetime {
            self.end_datetime = DateFormatter.iso8601WithoutFractionalSeconds.date(from: date)
        }
        
        self.created_at = nil
        if let date = created_at {
            self.created_at = DateFormatter.iso8601WithFractionalSeconds.date(from: date)
        }
        
    }
}
