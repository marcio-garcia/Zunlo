//
//  EventOccurrence.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation

public struct EventOccurrence: Identifiable, Hashable {
    public let id: UUID
    let userId: UUID
    let eventId: UUID
    public let title: String
    let notes: String?
    public let startDate: Date
    public let endDate: Date
    public let isRecurring: Bool
    let location: String?
    let color: EventColor
    let reminderTriggers: [ReminderTrigger]?
    let isOverride: Bool
    let isCancelled: Bool
    let updatedAt: Date
    let createdAt: Date
    let overrides: [EventOverride]
    let recurrence_rules: [RecurrenceRule]
    let deletedAt: Date?
    let needsSync: Bool
    let isFakeOccForEmptyToday: Bool
    let version: Int?
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        eventId: UUID,
        title: String,
        notes: String?,
        startDate: Date,
        endDate: Date,
        isRecurring: Bool,
        location: String?,
        color: EventColor,
        reminderTriggers: [ReminderTrigger]?,
        isOverride: Bool,
        isCancelled: Bool,
        updatedAt: Date,
        createdAt: Date,
        overrides: [EventOverride],
        recurrence_rules: [RecurrenceRule],
        deletedAt: Date?,
        needsSync: Bool,
        isFakeOccForEmptyToday: Bool,
        version: Int?
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
        self.deletedAt = deletedAt
        self.needsSync = needsSync
        self.isFakeOccForEmptyToday = isFakeOccForEmptyToday
        self.version = version
    }
}

extension EventOccurrence {
    init(occ: EventOccurrenceResponse) {
        self.id = occ.id
        self.userId = occ.user_id
        self.eventId = occ.id
        self.title = occ.title
        self.notes = occ.notes
        self.startDate = occ.start_datetime
        self.endDate = occ.end_datetime
        self.isRecurring = occ.is_recurring
        self.location = occ.location
        self.color = EventColor(rawValue: occ.color ?? "") ?? .yellow
        self.reminderTriggers = occ.reminderTriggers
        self.isOverride = false
        self.isCancelled = false
        self.updatedAt = occ.updated_at
        self.createdAt = occ.created_at
        self.overrides = occ.overrides.compactMap { EventOverride(remote: $0) }
        self.recurrence_rules = occ.recurrence_rules.compactMap { RecurrenceRule(remote: $0) }
        self.deletedAt = occ.deletedAt
        self.needsSync = occ.needsSync
        self.isFakeOccForEmptyToday = false
        self.version = occ.version
    }
}
//
//extension EventOccurrence: EventType {
//    public var recurrenceType: String? {
//        recurrence_rules.first?.freq.rawValue
//    }
//    
//    public var recurrenceInterval: Int? {
//        recurrence_rules.first?.interval
//    }
//    
//    public var byWeekday: [Int]? {
//        recurrence_rules.first?.byWeekday
//    }
//    
//    public var byMonthday: [Int]? {
//        recurrence_rules.first?.byMonthday
//    }
//    
//    public var until: Date? {
//        recurrence_rules.first?.until
//    }
//    
//    public var count: Int? {
//        recurrence_rules.first?.count
//    }
//}
