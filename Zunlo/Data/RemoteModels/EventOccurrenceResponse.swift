//
//  EventOccurrenceRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/10/25.
//

import Foundation

struct EventOccurrenceResponse: Codable, Identifiable {
    let id: UUID
    let user_id: UUID
    let title: String
    let notes: String?
    let start_datetime: Date
    let end_datetime: Date?
    let is_recurring: Bool
    let location: String?
    let created_at: Date
    let updated_at: Date
    let color: String?
    let reminderTriggers: [ReminderTrigger]?
    let overrides: [EventOverrideRemote]
    let recurrence_rules: [RecurrenceRuleRemote]
    
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        self.id = try container.decodeSafely(UUID.self, forKey: .id)
//        self.user_id = try container.decodeSafely(UUID.self, forKey: .user_id)
//        self.title = try container.decodeSafely(String.self, forKey: .title)
//        self.notes = try? container.decodeSafely(String.self, forKey: .notes)
//        self.is_recurring = try container.decodeSafely(Bool.self, forKey: .is_recurring)
//        self.location = try? container.decodeSafely(String.self, forKey: .location)
//        self.color = try? container.decodeSafely(String.self, forKey: .color)
//        self.overrides = try container.decode([EventOverrideRemote].self, forKey: .overrides)
//        self.recurrence_rules = try container.decode([RecurrenceRuleRemote].self, forKey: .recurrence_rules)
//        
//        let start_datetime = try container.decode(String.self, forKey: .start_datetime)
//        let end_datetime = try? container.decodeSafely(String.self, forKey: .end_datetime)
//        let created_at = try container.decodeSafely(String.self, forKey: .created_at)
//        let updated_at = try container.decodeSafely(String.self, forKey: .updated_at)
//        
//        self.start_datetime = DateFormatter.iso8601WithoutFractionalSeconds.date(from: start_datetime) ?? Date()
//        self.updated_at = DateFormatter.iso8601WithoutFractionalSeconds.date(from: updated_at) ?? Date()
//        
//        let date = end_datetime ?? Date().ISO8601Format()
//        self.end_datetime = DateFormatter.iso8601WithoutFractionalSeconds.date(from: date)
//        
//        self.created_at = DateFormatter.iso8601WithFractionalSeconds.date(from: created_at) ?? Date()
//    }
}

extension EventOccurrenceResponse {
    init(local e: EventLocal,
         overrides ovs: [EventOverrideLocal],
         rules rrs: [RecurrenceRuleLocal]) {

        self.id = e.id
        self.user_id = e.userId ?? UUID()
        self.title = e.title
        self.notes = e.notes
        self.start_datetime = e.startDate
        self.end_datetime = e.endDate
        self.is_recurring = e.isRecurring
        self.location = e.location
        self.created_at = e.createdAt
        self.updated_at = e.updatedAt
        self.color = e.color?.rawValue
        self.reminderTriggers = e.reminderTriggersArray

        // Map children → Remote DTOs; keep deterministic order by id to match SQL
        self.overrides = ovs
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { EventOverrideRemote(local: $0) }

        self.recurrence_rules = rrs
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { RecurrenceRuleRemote(local: $0) }
    }
}
