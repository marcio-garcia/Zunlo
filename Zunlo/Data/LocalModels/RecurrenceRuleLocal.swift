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
    @Persisted var byWeekday = List<Int>()   // No need for optional; can be empty
    @Persisted var byMonthday = List<Int>()
    @Persisted var byMonth = List<Int>()
    @Persisted var until: Date?
    @Persisted var count: Int?
    @Persisted var createdAt: Date
    @Persisted var updatedAt: Date

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
        updatedAt: Date
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
    }
}
