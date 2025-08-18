//
//  RecurrenceRuleRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation

public struct RecurrenceRuleRemote: Codable, Identifiable {
    public var id: UUID
    public var event_id: UUID
    public var freq: String
    public var interval: Int
    public var byweekday: [Int]?
    public var bymonthday: [Int]?
    public var bymonth: [Int]?
    public var until: Date?
    public var count: Int?
    public var created_at: Date
    public var updated_at: Date
    public var deleted_at: Date? = nil
    public var version: Int?
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
        self.version = local.version
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
        self.version = domain.version
    }
}
