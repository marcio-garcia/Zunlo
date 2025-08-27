//
//  RecurrenceRuleRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation

extension RecurrenceRuleRemote {
    var isInsertCandidate: Bool { version == nil }
}

public struct RecurrenceRuleRemote: RemoteEntity, Codable, Identifiable {
    public var id: UUID
    public var eventId: UUID
    public var freq: String
    public var interval: Int
    public var byweekday: [Int]?
    public var bymonthday: [Int]?
    public var bymonth: [Int]?
    public var until: Date?
    public var count: Int?
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedAtRaw: String?
    public var deletedAt: Date? = nil
    public var version: Int?
}

extension RecurrenceRuleRemote {
    internal init(local: RecurrenceRuleLocal) {
        self.id = local.id
        self.eventId = local.eventId
        self.freq = local.freq
        self.interval = local.interval
        self.byweekday = local.byWeekdayArray
        self.bymonthday = local.byMonthdayArray
        self.bymonth = local.byMonthArray
        self.until = local.until
        self.count = local.count
        self.createdAt = local.createdAt
        self.updatedAt = local.updatedAt
        self.deletedAt = local.deletedAt
        self.version = local.version
    }
    
    init(domain: RecurrenceRule) {
        self.id = domain.id
        self.eventId = domain.eventId
        self.freq = domain.freq.rawValue
        self.interval = domain.interval
        self.byweekday = domain.byWeekday
        self.bymonthday = domain.byMonthday
        self.bymonth = domain.byMonth
        self.until = domain.until
        self.count = domain.count
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
        self.deletedAt = domain.deletedAt
        self.version = domain.version
    }
}
