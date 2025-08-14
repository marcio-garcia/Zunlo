//
//  EventOverride.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation

struct EventOverride: Identifiable, Codable, Hashable {
    let id: UUID
    let eventId: UUID
    let occurrenceDate: Date
    let overriddenTitle: String?
    let overriddenStartDate: Date?
    let overriddenEndDate: Date?
    let overriddenLocation: String?
    let isCancelled: Bool
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let color: EventColor
    
    var deletedAt: Date? = nil
    var needsSync: Bool = false
}

extension EventOverride {
    init(remote: EventOverrideRemote) {
        self.id = remote.id
        self.eventId = remote.event_id
        self.occurrenceDate = remote.occurrence_date
        self.overriddenTitle = remote.overridden_title
        self.overriddenStartDate = remote.overridden_start_datetime
        self.overriddenEndDate = remote.overridden_end_datetime
        self.overriddenLocation = remote.overridden_location
        self.isCancelled = remote.is_cancelled
        self.notes = remote.notes
        self.createdAt = remote.created_at
        self.updatedAt = remote.updated_at
        self.color = remote.color ?? .yellow
        self.deletedAt = remote.deleted_at
        self.needsSync = false
    }

    init(local: EventOverrideLocal) {
        self.id = local.id
        self.eventId = local.eventId
        self.occurrenceDate = local.occurrenceDate
        self.overriddenTitle = local.overriddenTitle
        self.overriddenStartDate = local.overriddenStartDate
        self.overriddenEndDate = local.overriddenEndDate
        self.overriddenLocation = local.overriddenLocation
        self.isCancelled = local.isCancelled
        self.notes = local.notes
        self.createdAt = local.createdAt
        self.updatedAt = local.updatedAt
        self.color = local.color ?? .yellow
        self.deletedAt = local.deletedAt
    }
}
