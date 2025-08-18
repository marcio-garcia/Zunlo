//
//  EventOverrideRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation

public struct EventOverrideRemote: Codable, Identifiable {
    public var id: UUID
    public var event_id: UUID
    public var occurrence_date: Date
    public var overridden_title: String?
    public var overridden_start_datetime: Date?
    public var overridden_end_datetime: Date?
    public var overridden_location: String?
    public var is_cancelled: Bool
    public var notes: String?
    public var created_at: Date
    public var updated_at: Date
    public var color: EventColor?
    public var deleted_at: Date?
    public var version: Int?
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
        self.color = domain.color
        self.deleted_at = domain.deletedAt
        self.version = domain.version
    }
    
    init(local: EventOverrideLocal) {
        self.id = local.id
        self.event_id = local.eventId
        self.occurrence_date = local.occurrenceDate
        self.overridden_title = local.overriddenTitle
        self.overridden_start_datetime = local.overriddenStartDate
        self.overridden_end_datetime = local.overriddenEndDate
        self.overridden_location = local.overriddenLocation
        self.is_cancelled = local.isCancelled
        self.notes = local.notes
        self.created_at = local.createdAt
        self.updated_at = local.updatedAt
        self.color = local.color
        self.deleted_at = local.deletedAt
        self.version = local.version
    }
}
