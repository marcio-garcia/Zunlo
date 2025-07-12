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
    let isFakeOccForEmptyToday: Bool
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        eventId: UUID,
        title: String,
        description: String? = nil,
        startDate: Date,
        endDate: Date? = nil,
        isRecurring: Bool = false,
        location: String? = nil,
        color: EventColor,
        isOverride: Bool = false,
        isCancelled: Bool = false,
        updatedAt: Date,
        createdAt: Date,
        overrides: [EventOverride] = [],
        recurrence_rules: [RecurrenceRule] = [],
        isFakeOccForEmptyToday: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.eventId = eventId
        self.title = title
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.isRecurring = isRecurring
        self.location = location
        self.color = color
        self.isOverride = isOverride
        self.isCancelled = isCancelled
        self.updatedAt = updatedAt
        self.createdAt = createdAt
        self.overrides = overrides
        self.recurrence_rules = recurrence_rules
        self.isFakeOccForEmptyToday = isFakeOccForEmptyToday
    }
}
