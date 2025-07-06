//
//  RecurrenceRuleRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation

struct RecurrenceRuleRemote: Codable, Identifiable {
    var id: UUID?
    let event_id: UUID
    let freq: String
    let interval: Int
    let byweekday: [Int]?
    let bymonthday: [Int]?
    let bymonth: [Int]?
    var until: Date?
    let count: Int?
    let created_at: Date
    let updated_at: Date
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? container.decodeSafely(UUID.self, forKey: .id)
        self.event_id = try container.decodeSafely(UUID.self, forKey: .event_id)
        self.freq = try container.decodeSafely(String.self, forKey: .freq)
        self.interval = try container.decodeSafely(Int.self, forKey: .interval)
        self.byweekday = try? container.decodeSafely([Int].self, forKey: .byweekday)
        self.bymonthday = try? container.decodeSafely([Int].self, forKey: .bymonthday)
        self.bymonth = try? container.decodeSafely([Int].self, forKey: .bymonth)
        self.count = try? container.decodeSafely(Int.self, forKey: .count)
        
        let until = try? container.decodeSafely(String.self, forKey: .until)
        let created_at = try container.decodeSafely(String.self, forKey: .created_at)
        let updated_at = try container.decodeSafely(String.self, forKey: .updated_at)
        
        self.until = nil
        if let date = until {
            self.until = DateFormatter.iso8601WithoutFractionalSeconds.date(from: date)
        }
        
        self.created_at = DateFormatter.iso8601WithFractionalSeconds.date(from: created_at) ?? Date()
        self.updated_at = DateFormatter.iso8601WithoutFractionalSeconds.date(from: updated_at) ?? Date()
    }
}
