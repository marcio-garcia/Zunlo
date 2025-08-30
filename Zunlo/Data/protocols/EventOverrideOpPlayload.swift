//
//  EventOverrideOpPlayload.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/27/25.
//

import Foundation

// MARK: - Task payloads (server owns created_at/updated_at)
public struct EventOverrideInsertPayload: Encodable {
    let id: UUID
    let event_id: UUID
    let occurrence_date: String
    let overridden_title: String?
    let overridden_start_datetime: String?
    let overridden_end_datetime: String?
    let overridden_location: String?
    let is_cancelled: Bool
    let notes: String?
    let color: EventColor?
    let deletedAt: String?
    
    init(remote r: EventOverrideRemote) {
        id = r.id
        event_id = r.eventId
        occurrence_date = RFC3339MicrosUTC.string(r.occurrenceDate)
        overridden_title = r.overriddenTitle
        overridden_start_datetime = r.overriddenStartDate.map(RFC3339MicrosUTC.string)
        overridden_end_datetime = r.overriddenEndDate.map(RFC3339MicrosUTC.string)
        overridden_location = r.overriddenLocation
        is_cancelled = r.isCancelled
        notes = r.notes
        color = r.color
        deletedAt = r.deletedAt.map(RFC3339MicrosUTC.string)
    }
}

public struct EventOverrideUpdatePayload: Encodable {
    // PATCH-style optionals (send all for now = minimal change; you can sparsify later)
    let event_id: UUID
    let occurrence_date: String
    let overridden_title: String?
    let overridden_start_datetime: String?
    let overridden_end_datetime: String?
    let overridden_location: String?
    let is_cancelled: Bool
    let notes: String?
    let color: EventColor?
    let deletedAt: String?

    static func full(from r: EventOverrideRemote) -> EventOverrideUpdatePayload {
        .init(
            event_id: r.eventId,
            occurrence_date: RFC3339MicrosUTC.string(r.occurrenceDate),
            overridden_title: r.overriddenTitle,
            overridden_start_datetime: r.overriddenStartDate.map(RFC3339MicrosUTC.string),
            overridden_end_datetime: r.overriddenEndDate.map(RFC3339MicrosUTC.string),
            overridden_location: r.overriddenLocation,
            is_cancelled: r.isCancelled,
            notes: r.notes,
            color: r.color,
            deletedAt: r.deletedAt.map(RFC3339MicrosUTC.string)
        )
    }
}
