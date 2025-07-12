//
//  Mapping+EventOccurrence.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/10/25.
//

import Foundation

extension EventOccurrence {
    init(remote: EventOccurrenceRemote) {
        self.id = remote.id
        self.userId = remote.user_id
        self.eventId = remote.id
        self.title = remote.title
        self.description = remote.description
        self.startDate = remote.start_datetime
        self.endDate = remote.end_datetime
        self.isRecurring = remote.is_recurring
        self.location = remote.location
        self.color = EventColor(rawValue: remote.color ?? "") ?? .yellow
        self.isOverride = false
        self.isCancelled = false
        self.updatedAt = remote.updated_at
        self.createdAt = remote.created_at
        self.overrides = remote.overrides.compactMap { EventOverride(remote: $0) }
        self.recurrence_rules = remote.recurrence_rules.compactMap { RecurrenceRule(remote: $0) }
        self.isFakeOccForEmptyToday = false
    }
}
