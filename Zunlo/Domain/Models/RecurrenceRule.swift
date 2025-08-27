//
//  RecurrenceRule.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation

struct RecurrenceRule: Identifiable, Codable, Hashable {
    let id: UUID
    let eventId: UUID
    let freq: RecurrenceFrequesncy
    let interval: Int
    let byWeekday: [Int]?
    let byMonthday: [Int]?
    let byMonth: [Int]?
    let until: Date?
    let count: Int?
    let createdAt: Date
    let updatedAt: Date
    
    var deletedAt: Date? = nil
    var needsSync: Bool = false
    var version: Int?          // <-- NEW (nil means “unknown / never synced”)
}

extension RecurrenceRule {
    init(remote: RecurrenceRuleRemote) {
        self.id = remote.id
        self.eventId = remote.eventId
        self.freq = RecurrenceFrequesncy(rawValue: remote.freq) ?? .daily
        self.interval = remote.interval
        self.byWeekday = remote.byweekday
        self.byMonthday = remote.bymonthday
        self.byMonth = remote.bymonth
        self.until = remote.until
        self.count = remote.count
        self.createdAt = remote.createdAt
        self.updatedAt = remote.updatedAt
        self.deletedAt = remote.deletedAt
        self.needsSync = false
    }

    init(local: RecurrenceRuleLocal) {
        self.id = local.id
        self.eventId = local.eventId
        self.freq = RecurrenceFrequesncy(rawValue: local.freq) ?? .daily
        self.interval = local.interval
        self.byWeekday = local.byWeekdayArray
        self.byMonthday = local.byMonthdayArray
        self.byMonth = local.byMonthArray
        self.until = local.until
        self.count = local.count
        self.createdAt = local.createdAt
        self.updatedAt = local.updatedAt
    }
}
