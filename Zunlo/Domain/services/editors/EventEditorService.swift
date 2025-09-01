//
//  EventEditorService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation
import SmartParseKit

// Use cases your VM and Quick Add can both call.
protocol EventEditorService {
    func add(_ input: AddEventInput) async throws
    func editAll(event: EventOccurrence, with input: EditEventInput, oldRule: RecurrenceRule?) async throws
    func editSingle(parent: EventOccurrence, occurrence: EventOccurrence, with input: EditEventInput) async throws
    func editOverride(_ override: EventOverride, with input: EditEventInput) async throws
    func editFuture(parent: EventOccurrence, startingFrom occurrence: EventOccurrence, with input: EditEventInput) async throws
    func delete(event: EventOccurrence) async throws
}

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
