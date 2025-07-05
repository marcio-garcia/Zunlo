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
    let until: Date?
    let count: Int?
    let created_at: Date
    let updated_at: Date
}
