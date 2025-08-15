//
//  RecurrenceRuleRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation

struct RecurrenceRuleRemote: Codable, Identifiable {
    var id: UUID
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
    
    var deleted_at: Date? = nil
    var version: Int? = nil
    
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        self.id = try? container.decodeSafely(UUID.self, forKey: .id)
//        self.event_id = try container.decodeSafely(UUID.self, forKey: .event_id)
//        self.freq = try container.decodeSafely(String.self, forKey: .freq)
//        self.interval = try container.decodeSafely(Int.self, forKey: .interval)
//        self.byweekday = try? container.decodeSafely([Int].self, forKey: .byweekday)
//        self.bymonthday = try? container.decodeSafely([Int].self, forKey: .bymonthday)
//        self.bymonth = try? container.decodeSafely([Int].self, forKey: .bymonth)
//        self.count = try? container.decodeSafely(Int.self, forKey: .count)
//        
//        let until = try? container.decodeSafely(String.self, forKey: .until)
//        let created_at = try container.decodeSafely(String.self, forKey: .created_at)
//        let updated_at = try container.decodeSafely(String.self, forKey: .updated_at)
//        
//        self.until = nil
//        if let date = until {
//            self.until = DateFormatter.iso8601WithoutFractionalSeconds.date(from: date)
//        }
//        
//        self.created_at = DateFormatter.iso8601WithFractionalSeconds.date(from: created_at) ?? Date()
//        self.updated_at = DateFormatter.iso8601WithoutFractionalSeconds.date(from: updated_at) ?? Date()
//    }
}

extension RecurrenceRuleRemote {
    internal init(local: RecurrenceRuleLocal) {
        self.id = local.id
        self.event_id = local.eventId
        self.freq = local.freq
        self.interval = local.interval
        self.byweekday = local.byWeekdayArray
        self.bymonthday = local.byMonthdayArray
        self.bymonth = local.byMonthArray
        self.until = local.until
        self.count = local.count
        self.created_at = local.createdAt
        self.updated_at = local.updatedAt
        self.deleted_at = local.deletedAt
        self.version = nil
    }
    
    init(domain: RecurrenceRule) {
        self.id = domain.id
        self.event_id = domain.eventId
        self.freq = domain.freq.rawValue
        self.interval = domain.interval
        self.byweekday = domain.byWeekday
        self.bymonthday = domain.byMonthday
        self.bymonth = domain.byMonth
        self.until = domain.until
        self.count = domain.count
        self.created_at = domain.createdAt
        self.updated_at = domain.updatedAt
        self.deleted_at = domain.deletedAt
        self.version = nil
    }
}
