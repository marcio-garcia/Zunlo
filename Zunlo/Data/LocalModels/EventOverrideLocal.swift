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
    @Persisted var eventId: UUID
    @Persisted var occurrenceDate: Date
    @Persisted var overriddenTitle: String?
    @Persisted var overriddenStartDate: Date?
    @Persisted var overriddenEndDate: Date?
    @Persisted var overriddenLocation: String?
    @Persisted var isCancelled: Bool = false
    @Persisted var notes: String?
    @Persisted var createdAt: Date
    @Persisted var updatedAt: Date

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
        updatedAt: Date
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
    }
}
