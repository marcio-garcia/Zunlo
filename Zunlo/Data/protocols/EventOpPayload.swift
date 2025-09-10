//
//  EventOpPayload.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/27/25.
//

import Foundation

// MARK: - Task payloads (server owns created_at/updated_at)
public struct EventInsertPayload: Encodable {
    let id: UUID
    let user_id: UUID
    let title: String
    let notes: String?
    let start_datetime: String
    let end_datetime: String?
    let is_recurring: Bool
    let location: String?
    let color: EventColor?
    let reminder_triggers: [ReminderTrigger]?
    let deleted_at: String?
    
    init(remote r: EventRemote) {
        id = r.id
        user_id = r.user_id
        title = r.title
        notes = r.notes
        start_datetime = RFC3339MicrosUTC.string(r.start_datetime)
        end_datetime = RFC3339MicrosUTC.string(r.end_datetime)
        is_recurring = r.is_recurring
        location = r.location
        color = r.color
        reminder_triggers = r.reminder_triggers
        deleted_at = r.deletedAt.map(RFC3339MicrosUTC.string)
    }
}

public struct EventUpdatePayload: Encodable {
    // PATCH-style optionals (send all for now = minimal change; you can sparsify later)
    let title: String?
    let notes: String?
    let start_datetime: String
    let end_datetime: String?
    let is_recurring: Bool
    let location: String?
    let color: EventColor?
    let reminder_triggers: [ReminderTrigger]?
    let deleted_at: String?
    
    static func full(from r: EventRemote) -> EventUpdatePayload {
        .init(
            title: r.title,
            notes: r.notes,
            start_datetime: RFC3339MicrosUTC.string(r.start_datetime),
            end_datetime: RFC3339MicrosUTC.string(r.end_datetime),
            is_recurring: r.is_recurring,
            location: r.location,
            color: r.color,
            reminder_triggers: r.reminder_triggers,
            deleted_at: r.deletedAt.map(RFC3339MicrosUTC.string)
        )
    }
}
