//
//  EventOverrideLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation
import RealmSwift

class EventOverrideLocal: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted(indexed: true) var eventId: UUID
    @Persisted var occurrenceDate: Date
    @Persisted var overriddenTitle: String?
    @Persisted var overriddenStartDate: Date?
    @Persisted var overriddenEndDate: Date?
    @Persisted var overriddenLocation: String?
    @Persisted var isCancelled: Bool = false
    @Persisted var notes: String?
    @Persisted var createdAt: Date
    @Persisted var updatedAt: Date
    @Persisted var color: EventColor? = .yellow
    
    @Persisted var deletedAt: Date? = nil
    @Persisted var needsSync: Bool = false

    // Convenience initializer
    convenience init(
        id: UUID,
        eventId: UUID,
        occurrenceDate: Date,
        overriddenTitle: String?,
        overriddenStartDate: Date?,
        overriddenEndDate: Date?,
        overriddenLocation: String?,
        isCancelled: Bool,
        notes: String?,
        createdAt: Date,
        updatedAt: Date,
        color: EventColor? = .yellow,
        deletedAt: Date? = nil,
        needsSync: Bool = false
    ) {
        self.init()
        self.id = id
        self.eventId = eventId
        self.occurrenceDate = occurrenceDate
        self.overriddenTitle = overriddenTitle
        self.overriddenStartDate = overriddenStartDate
        self.overriddenEndDate = overriddenEndDate
        self.overriddenLocation = overriddenLocation
        self.isCancelled = isCancelled
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.color = color
        self.deletedAt = deletedAt
        self.needsSync = needsSync
    }
}

extension EventOverrideLocal {
    convenience init(domain: EventOverride) {
        self.init(
            id: domain.id,
            eventId: domain.eventId,
            occurrenceDate: domain.occurrenceDate,
            overriddenTitle: domain.overriddenTitle,
            overriddenStartDate: domain.overriddenStartDate,
            overriddenEndDate: domain.overriddenEndDate,
            overriddenLocation: domain.overriddenLocation,
            isCancelled: domain.isCancelled,
            notes: domain.notes,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt,
            color: domain.color
        )
    }
    
    convenience init(remote: EventOverrideRemote) {
        self.init(id: remote.id,
                  eventId: remote.event_id,
                  occurrenceDate: remote.occurrence_date,
                  overriddenTitle: remote.overridden_title,
                  overriddenStartDate: remote.overridden_start_datetime,
                  overriddenEndDate: remote.overridden_end_datetime,
                  overriddenLocation: remote.overridden_location,
                  isCancelled: remote.is_cancelled,
                  notes: remote.notes,
                  createdAt: remote.created_at,
                  updatedAt: remote.updated_at,
                  color: remote.color ?? .yellow,
                  deletedAt: remote.deleted_at,
                  needsSync: false
        )
    }
    
    func getUpdateFields(_ remote: EventOverrideRemote) {
        self.occurrenceDate = remote.occurrence_date
        self.overriddenTitle = remote.overridden_title
        self.overriddenStartDate = remote.overridden_start_datetime
        self.overriddenEndDate = remote.overridden_end_datetime
        self.overriddenLocation = remote.overridden_location
        self.isCancelled = remote.is_cancelled
        self.notes = remote.notes
        self.updatedAt = remote.updated_at
        self.color = remote.color ?? .yellow
        self.deletedAt = remote.deleted_at
        self.needsSync = false
    }
    
    func getUpdateFields(_ domain: EventOverride) {
        self.occurrenceDate = domain.occurrenceDate
        self.overriddenTitle = domain.overriddenTitle
        self.overriddenStartDate = domain.overriddenStartDate
        self.overriddenEndDate = domain.overriddenEndDate
        self.overriddenLocation = domain.overriddenLocation
        self.isCancelled = domain.isCancelled
        self.notes = domain.notes
        self.updatedAt = Date()
        self.color = domain.color
        self.deletedAt = domain.deletedAt
        self.needsSync = true
    }
}
