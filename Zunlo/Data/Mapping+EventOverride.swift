//
//  Mapping+EventOverride.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation

extension EventOverride {
    init(remote: EventOverrideRemote) {
        guard let id = remote.id else {
            fatalError("Error mapping remote to local: invalid id.")
        }
        self.id = id
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
    }
}

extension EventOverrideRemote {
    init(domain: EventOverride) {
        self.id = domain.id
        self.event_id = domain.eventId
        self.occurrence_date = domain.occurrenceDate
        self.overridden_title = domain.overriddenTitle
        self.overridden_start_datetime = domain.overriddenStartDate
        self.overridden_end_datetime = domain.overriddenEndDate
        self.overridden_location = domain.overriddenLocation
        self.is_cancelled = domain.isCancelled
        self.notes = domain.notes
        self.created_at = domain.createdAt
        self.updated_at = domain.updatedAt
    }
}

extension EventOverrideLocal {
    convenience init(domain: EventOverride) {
        guard let id = domain.id else {
            fatalError("Error mapping domain to local: invalid id.")
        }
        self.init(
            id: id,
            eventId: domain.eventId,
            occurrenceDate: domain.occurrenceDate,
            overriddenTitle: domain.overriddenTitle,
            overriddenStartDate: domain.overriddenStartDate,
            overriddenEndDate: domain.overriddenEndDate,
            overriddenLocation: domain.overriddenLocation,
            isCancelled: domain.isCancelled,
            notes: domain.notes,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt
        )
    }
    
    convenience init(remote: EventOverrideRemote) {
        guard let id = remote.id else {
            fatalError("Error mapping remote to local: invalid id.")
        }
        self.init(id: id,
                  eventId: remote.event_id,
                  occurrenceDate: remote.occurrence_date,
                  overriddenTitle: remote.overridden_title,
                  overriddenStartDate: remote.overridden_start_datetime,
                  overriddenEndDate: remote.overridden_end_datetime,
                  overriddenLocation: remote.overridden_location,
                  isCancelled: remote.is_cancelled,
                  notes: remote.notes,
                  createdAt: remote.created_at,
                  updatedAt: remote.updated_at
        )
    }
    
    func getUpdateFields(_ local: EventOverrideRemote) {
        self.occurrenceDate = local.occurrence_date
        self.overriddenTitle = local.overridden_title
        self.overriddenStartDate = local.overridden_start_datetime
        self.overriddenEndDate = local.overridden_end_datetime
        self.overriddenLocation = local.overridden_location
        self.isCancelled = local.is_cancelled
        self.notes = local.notes
        self.updatedAt = local.updated_at
    }
}
