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
    var version: Int?          // <-- NEW (nil means “unknown / never synced”)
}

extension EventOverride {
    init(remote: EventOverrideRemote) {
        self.id = remote.id
        self.eventId = remote.eventId
        self.occurrenceDate = remote.occurrenceDate
        self.overriddenTitle = remote.overriddenTitle
        self.overriddenStartDate = remote.overriddenStartDate
        self.overriddenEndDate = remote.overriddenEndDate
        self.overriddenLocation = remote.overriddenLocation
        self.isCancelled = remote.isCancelled
        self.notes = remote.notes
        self.createdAt = remote.createdAt
        self.updatedAt = remote.updatedAt
        self.color = remote.color ?? .yellow
        self.deletedAt = remote.deletedAt
        self.needsSync = false
        self.version = remote.version
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
        self.version = local.version
    }
}
