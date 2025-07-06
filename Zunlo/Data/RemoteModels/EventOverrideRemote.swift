//
//  EventOverrideRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation

struct EventOverrideRemote: Codable, Identifiable {
    var id: UUID?
    let event_id: UUID
    let occurrence_date: Date
    let overridden_title: String?
    var overridden_start_datetime: Date?
    var overridden_end_datetime: Date?
    let overridden_location: String?
    let is_cancelled: Bool
    let notes: String?
    let created_at: Date
    let updated_at: Date
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? container.decodeSafely(UUID.self, forKey: .id)
        self.event_id = try container.decodeSafely(UUID.self, forKey: .event_id)
        self.overridden_title = try? container.decodeSafely(String.self, forKey: .overridden_title)
        self.overridden_location = try? container.decodeSafely(String.self, forKey: .overridden_location)
        self.is_cancelled = try container.decodeSafely(Bool.self, forKey: .is_cancelled)
        self.notes = try? container.decodeSafely(String.self, forKey: .notes)
        
        
        let occurrence_date = try container.decodeSafely(String.self, forKey: .occurrence_date)
        let overridden_start_datetime = try? container.decodeSafely(String.self, forKey: .overridden_start_datetime)
        let overridden_end_datetime = try? container.decodeSafely(String.self, forKey: .overridden_end_datetime)
        let created_at = try container.decodeSafely(String.self, forKey: .created_at)
        let updated_at = try container.decodeSafely(String.self, forKey: .updated_at)
        
        self.occurrence_date = DateFormatter.iso8601WithoutFractionalSeconds.date(from: occurrence_date) ?? Date()
        
        self.overridden_start_datetime = nil
        if let date = overridden_start_datetime {
            self.overridden_start_datetime = DateFormatter.iso8601WithoutFractionalSeconds.date(from: date) ?? Date()
        }
        
        self.overridden_end_datetime = nil
        if let date = overridden_end_datetime {
            self.overridden_end_datetime = DateFormatter.iso8601WithoutFractionalSeconds.date(from: date) ?? Date()
        }
        
        self.created_at = DateFormatter.iso8601WithFractionalSeconds.date(from: created_at) ?? Date()
        self.updated_at = DateFormatter.iso8601WithoutFractionalSeconds.date(from: updated_at) ?? Date()
    }
}
