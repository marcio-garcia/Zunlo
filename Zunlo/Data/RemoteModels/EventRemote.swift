//
//  EventRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

public struct EventRemote: Codable, Identifiable {
    public var id: UUID
    public var user_id: UUID?
    public var title: String
    public var notes: String?
    public var start_datetime: Date
    public var end_datetime: Date?
    public var is_recurring: Bool
    public var location: String?
    public var created_at: Date?
    public var updated_at: Date
    public var color: EventColor?
    public var reminder_triggers: [ReminderTrigger]?
    public var deleted_at: Date?
    public var version: Int?
}

extension EventRemote {
    init(domain: Event) {
        self.id = domain.id
        self.user_id = nil // omit so DEFAULT auth.uid() applies on insert
        self.title = domain.title
        self.notes = domain.notes
        self.start_datetime = domain.startDate
        self.end_datetime = domain.endDate
        self.is_recurring = domain.isRecurring
        self.location = domain.location
        self.created_at = domain.createdAt // ok to send or omit; server can default too
        self.updated_at = domain.updatedAt // server trigger will bump anyway
        self.color = domain.color
        self.reminder_triggers = domain.reminderTriggers
        
        self.deleted_at = domain.deletedAt
        self.version = domain.version
    }
    
    init(local: EventLocal) {
        self.id = local.id
        self.user_id = nil // omit so DEFAULT auth.uid() applies on insert
        self.title = local.title
        self.notes = local.notes
        self.start_datetime = local.startDate
        self.end_datetime = local.endDate
        self.is_recurring = local.isRecurring
        self.location = local.location
        self.created_at = local.createdAt
        self.updated_at = local.updatedAt
        self.color = local.color
        self.reminder_triggers = local.reminderTriggersArray
    
        self.deleted_at = local.deletedAt
        self.version = local.version
    }
}
