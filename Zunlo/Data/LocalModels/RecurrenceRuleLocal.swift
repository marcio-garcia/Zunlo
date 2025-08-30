//
//  RecurrenceRuleLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation
import RealmSwift

class RecurrenceRuleLocal: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted(indexed: true) var eventId: UUID
    @Persisted var freq: String
    @Persisted var interval: Int
    @Persisted var byWeekday = List<Int>()
    @Persisted var byMonthday = List<Int>()
    @Persisted var byMonth = List<Int>()
    @Persisted var until: Date?
    @Persisted var count: Int?
    @Persisted var createdAt: Date
    @Persisted var updatedAt: Date
    @Persisted var deletedAt: Date? = nil
    @Persisted var needsSync: Bool = false
    @Persisted var version: Int?

    var byWeekdayArray: [Int] {
        get { Array(byWeekday) }
        set {
            byWeekday.removeAll()
            byWeekday.append(objectsIn: newValue)
        }
    }
    
    var byMonthdayArray: [Int] {
        get { Array(byMonthday) }
        set {
            byMonthday.removeAll()
            byMonthday.append(objectsIn: newValue)
        }
    }
    
    var byMonthArray: [Int] {
        get { Array(byMonth) }
        set {
            byMonth.removeAll()
            byMonth.append(objectsIn: newValue)
        }
    }
    
    // Realm models need a default (parameterless) initializer for reads/writes.
    // Custom init for convenience (optional):
    convenience init(
        id: UUID,
        eventId: UUID,
        freq: String,
        interval: Int,
        byWeekday: [Int]?,
        byMonthday: [Int]?,
        byMonth: [Int]?,
        until: Date?,
        count: Int?,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date?,
        needsSync: Bool = false,
        version: Int?
    ) {
        self.init()
        self.id = id
        self.eventId = eventId
        self.freq = freq
        self.interval = interval
        if let byWeekday { self.byWeekday.append(objectsIn: byWeekday) }
        if let byMonthday { self.byMonthday.append(objectsIn: byMonthday) }
        if let byMonth { self.byMonth.append(objectsIn: byMonth) }
        self.until = until
        self.count = count
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.needsSync = needsSync
        self.version = version
    }
}

extension RecurrenceRuleLocal {
    convenience init(domain: RecurrenceRule) {
        self.init(
            id: domain.id,
            eventId: domain.eventId,
            freq: domain.freq.rawValue,
            interval: domain.interval,
            byWeekday: domain.byWeekday,
            byMonthday: domain.byMonthday,
            byMonth: domain.byMonth,
            until: domain.until,
            count: domain.count,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt,
            deletedAt: domain.deletedAt,
            needsSync: true,
            version: domain.version
        )
    }
    
    convenience init(remote: RecurrenceRuleRemote) {
        self.init(id: remote.id,
                  eventId: remote.eventId,
                  freq: remote.freq,
                  interval: remote.interval,
                  byWeekday: remote.byweekday,
                  byMonthday: remote.bymonthday,
                  byMonth: remote.bymonth,
                  until: remote.until,
                  count: remote.count,
                  createdAt: remote.createdAt,
                  updatedAt: remote.updatedAt,
                  deletedAt: remote.deletedAt,
                  needsSync: false,
                  version: remote.version
        )
    }
    
    func getUpdateFields(remote: RecurrenceRuleRemote) {
        self.eventId = remote.eventId
        self.freq = remote.freq
        self.interval = remote.interval
        self.byWeekdayArray = remote.byweekday ?? []
        self.byMonthdayArray = remote.bymonthday ?? []
        self.byMonthArray = remote.bymonth ?? []
        self.until = remote.until
        self.count = remote.count
        self.createdAt = remote.createdAt
        self.updatedAt = remote.updatedAt
        self.deletedAt = remote.deletedAt
        self.needsSync = false
        self.version = remote.version
    }
    
    func getUpdateFields(domain: RecurrenceRule) {
        self.eventId = domain.eventId
        self.freq = domain.freq.rawValue
        self.interval = domain.interval
        self.byWeekdayArray = domain.byWeekday ?? []
        self.byMonthdayArray = domain.byMonthday ?? []
        self.byMonthArray = domain.byMonth ?? []
        self.until = domain.until
        self.count = domain.count
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
        self.deletedAt = domain.deletedAt
        self.needsSync = true
        self.version = domain.version
    }
}
