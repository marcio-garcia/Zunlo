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
    let freq: String
    let interval: Int
    let byWeekday: [Int]?
    let byMonthday: [Int]?
    let byMonth: [Int]?
    let until: Date?
    let count: Int?
    let createdAt: Date
    let updatedAt: Date
}
