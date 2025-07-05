//
//  EventOverrideLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation
import SwiftData

@Model
final class EventOverrideLocal {
    @Attribute(.unique) var id: UUID
    var eventId: UUID
    var occurrenceDate: Date
    var overriddenTitle: String?
    var overriddenStartDate: Date?
    var overriddenEndDate: Date?
    var overriddenLocation: String?
    var isCancelled: Bool
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
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
        updatedAt: Date
    ) {
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
    }
}
