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
    let notes: String?
    let startDate: Date
    let endDate: Date?
    let isRecurring: Bool
    let location: String?
    let color: EventColor
    let reminderTriggers: [ReminderTrigger]?
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
        notes: String? = nil,
        startDate: Date,
        endDate: Date? = nil,
        isRecurring: Bool = false,
        location: String? = nil,
        color: EventColor,
        reminderTriggers: [ReminderTrigger]? = nil,
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
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.isRecurring = isRecurring
        self.location = location
        self.color = color
        self.reminderTriggers = reminderTriggers
        self.isOverride = isOverride
        self.isCancelled = isCancelled
        self.updatedAt = updatedAt
        self.createdAt = createdAt
        self.overrides = overrides
        self.recurrence_rules = recurrence_rules
        self.isFakeOccForEmptyToday = isFakeOccForEmptyToday
    }
}

extension EventOccurrence {
    init(remote: EventOccurrenceResponse) {
        self.id = remote.id
        self.userId = remote.user_id
        self.eventId = remote.id
        self.title = remote.title
        self.notes = remote.notes
        self.startDate = remote.start_datetime
        self.endDate = remote.end_datetime
        self.isRecurring = remote.is_recurring
        self.location = remote.location
        self.color = EventColor(rawValue: remote.color ?? "") ?? .yellow
        self.reminderTriggers = []
        self.isOverride = false
        self.isCancelled = false
        self.updatedAt = remote.updated_at
        self.createdAt = remote.created_at
        self.overrides = remote.overrides.compactMap { EventOverride(remote: $0) }
        self.recurrence_rules = remote.recurrence_rules.compactMap { RecurrenceRule(remote: $0) }
        self.isFakeOccForEmptyToday = false
    }
}
