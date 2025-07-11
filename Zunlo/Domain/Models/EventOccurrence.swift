//
//  EventOccurrence.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation

struct EventOccurrence: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let eventId: UUID
    let title: String
    let description: String?
    let startDate: Date
    let endDate: Date?
    let isRecurring: Bool
    let location: String?
    let color: EventColor
    let isOverride: Bool
    let isCancelled: Bool
    let updatedAt: Date
    let createdAt: Date
    let overrides: [EventOverride]
    let recurrence_rules: [RecurrenceRule]
}
