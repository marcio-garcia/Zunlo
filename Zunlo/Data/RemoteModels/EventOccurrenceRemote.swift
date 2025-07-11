//
//  EventOccurrenceRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/10/25.
//

import Foundation

struct EventOccurrenceRemote: Codable, Identifiable {
    let id: UUID
    let user_id: UUID
    let title: String
    let description: String?
    let start_datetime: Date
    let end_datetime: Date?
    let is_recurring: Bool
    let location: String?
    let created_at: Date
    let updated_at: Date
    let color: String?
    let overrides: [EventOverrideRemote]
    let recurrence_rules: [RecurrenceRuleRemote]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeSafely(UUID.self, forKey: .id)
        self.user_id = try container.decodeSafely(UUID.self, forKey: .user_id)
        self.title = try container.decodeSafely(String.self, forKey: .title)
        self.description = try? container.decodeSafely(String.self, forKey: .description)
        self.is_recurring = try container.decodeSafely(Bool.self, forKey: .is_recurring)
        self.location = try? container.decodeSafely(String.self, forKey: .location)
        self.color = try? container.decodeSafely(String.self, forKey: .color)
        self.overrides = try container.decode([EventOverrideRemote].self, forKey: .overrides)
        self.recurrence_rules = try container.decode([RecurrenceRuleRemote].self, forKey: .recurrence_rules)
        
        let start_datetime = try container.decode(String.self, forKey: .start_datetime)
        let end_datetime = try? container.decodeSafely(String.self, forKey: .end_datetime)
        let created_at = try container.decodeSafely(String.self, forKey: .created_at)
        let updated_at = try container.decodeSafely(String.self, forKey: .updated_at)
        
        self.start_datetime = DateFormatter.iso8601WithoutFractionalSeconds.date(from: start_datetime) ?? Date()
        self.updated_at = DateFormatter.iso8601WithoutFractionalSeconds.date(from: updated_at) ?? Date()
        
        let date = end_datetime ?? Date().ISO8601Format()
        self.end_datetime = DateFormatter.iso8601WithoutFractionalSeconds.date(from: date)
        
        self.created_at = DateFormatter.iso8601WithFractionalSeconds.date(from: created_at) ?? Date()
    }
}
