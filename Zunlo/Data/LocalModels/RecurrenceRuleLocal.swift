//
//  RecurrenceRuleLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation
import SwiftData

@Model
final class RecurrenceRuleLocal {
    @Attribute(.unique) var id: UUID
    var eventId: UUID
    var freq: String
    var interval: Int
    var byWeekday: [Int]?
    var byMonthday: [Int]?
    var byMonth: [Int]?
    var until: Date?
    var count: Int?
    var createdAt: Date
    var updatedAt: Date

    init(
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
        self.id = id
        self.eventId = eventId
        self.freq = freq
        self.interval = interval
        self.byWeekday = byWeekday
        self.byMonthday = byMonthday
        self.byMonth = byMonth
        self.until = until
        self.count = count
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
