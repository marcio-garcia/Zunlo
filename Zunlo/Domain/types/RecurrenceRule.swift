//
//  RecurrenceRule.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/2/25.
//

enum RecurrenceRule: Codable, Equatable, Hashable {
    case none
    case daily
    case weekly(dayOfWeek: Int)    // 1 = Sunday, ... 7 = Saturday
    case monthly(day: Int)         // 1...31
}
