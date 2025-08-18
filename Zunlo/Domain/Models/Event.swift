//
//  Event.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/26/25.
//

import Foundation

struct Event: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: UUID?
    var title: String
    var notes: String?
    var startDate: Date
    var endDate: Date?
    var isRecurring: Bool
    var location: String?
    var createdAt: Date
    var updatedAt: Date
    var color: EventColor
    var reminderTriggers: [ReminderTrigger]?
    
    var deletedAt: Date?
    var needsSync: Bool
    var version: Int?          // <-- NEW (nil means “unknown / never synced”)
}

extension Event: SchedulableReminderItem {
    var dueDateForReminder: Date? { startDate } // or endDate?
}

extension Event {
    init(remote: EventRemote) {
        guard let created_at = remote.created_at else {
            fatalError("Error mapping remote to local: invalid id or created_at.")
        }
        self.id = remote.id
        self.userId = remote.user_id
        self.title = remote.title
        self.notes = remote.notes
        self.startDate = remote.start_datetime
        self.endDate = remote.end_datetime
        self.isRecurring = remote.is_recurring
        self.location = remote.location
        self.createdAt = created_at
        self.updatedAt = remote.updated_at
        self.color = remote.color ?? .yellow
        self.reminderTriggers = remote.reminder_triggers
        
        self.deletedAt = remote.deleted_at
        self.needsSync = false
        self.version = remote.version
    }

    init(local: EventLocal) {
        self.id = local.id
        self.userId = local.userId
        self.title = local.title
        self.notes = local.notes
        self.startDate = local.startDate
        self.endDate = local.endDate
        self.isRecurring = local.isRecurring
        self.location = local.location
        self.createdAt = local.createdAt
        self.updatedAt = local.updatedAt
        self.color = local.color ?? .yellow
        self.reminderTriggers = local.reminderTriggersArray
        
        self.deletedAt = local.deletedAt
        self.needsSync = local.needsSync
        self.version = local.version
    }
}
