//
//  AddEventInput.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/9/25.
//

import Foundation

// DTOs decouple UI from domain defaults/validation
struct AddEventInput {
    var id: UUID
    var userId: UUID
    var title: String
    var notes: String?
    var startDate: Date
    var endDate: Date
    var isRecurring: Bool
    var location: String?
    var color: EventColor
    var reminderTriggers: [ReminderTrigger]?
    // Recurrence bits (used when isRecurring)
    var recurrenceType: String?
    var recurrenceInterval: Int?
    var byWeekday: [Int]?
    var byMonthday: [Int]?
    var until: Date?
    var count: Int?
    var isCancelled: Bool
}

extension AddEventInput: EventType {}

typealias EditEventInput = AddEventInput
