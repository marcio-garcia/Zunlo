//
//  EventLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import Foundation
import RealmSwift

class EventLocal: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted(indexed: true) var userId: UUID?
    @Persisted var title: String = ""
    @Persisted var notes: String?
    @Persisted var startDate: Date = Date()
    @Persisted var endDate: Date?
    @Persisted var isRecurring: Bool = false
    @Persisted var location: String?
    @Persisted var createdAt: Date = Date()
    @Persisted var updatedAt: Date = Date()
    @Persisted var color: EventColor? = .yellow
    @Persisted var reminderTriggers: List<ReminderTriggerLocal>
    @Persisted var deletedAt: Date?
    @Persisted var needsSync: Bool = false
    @Persisted var version: Int?          // <-- NEW (nil means “unknown / never synced”)
    
    var reminderTriggersArray: [ReminderTrigger] {
        get {
            return reminderTriggers.map { $0.toDomain }
        }
        set {
            reminderTriggers.removeAll()
            newValue.forEach { rem in
                reminderTriggers.append(rem.toLocal())
            }
        }
    }
    
    convenience init(
        id: UUID,
        userId: UUID? = nil,
        title: String = "",
        notes: String? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        isRecurring: Bool = false,
        location: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        color: EventColor? = .yellow,
        reminderTriggers: [ReminderTrigger],
        deletedAt: Date? = nil,
        needsSync: Bool = false,
        version: Int?
    ) {
        self.init() // <-- MUST call the default init
        self.id = id
        self.userId = userId
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.isRecurring = isRecurring
        self.location = location
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.color = color
        self.reminderTriggersArray = reminderTriggers
        self.deletedAt = deletedAt
        self.needsSync = needsSync
        self.version = version
    }
}

extension EventLocal {
    convenience init(domain: Event) {
        self.init(
            id: domain.id,
            userId: domain.userId,
            title: domain.title,
            notes: domain.notes,
            startDate: domain.startDate,
            endDate: domain.endDate,
            isRecurring: domain.isRecurring,
            location: domain.location,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt,
            color: domain.color,
            reminderTriggers: domain.reminderTriggers ?? [],
            version: domain.version
        )
    }
    
    convenience init(remote: EventRemote) {
        guard let created_at = remote.created_at else {
            fatalError("Error mapping remote to local: created_at.")
        }
        self.init(
            id: remote.id,
            userId: remote.user_id,
            title: remote.title,
            notes: remote.notes,
            startDate: remote.start_datetime,
            endDate: remote.end_datetime,
            isRecurring: remote.is_recurring,
            location: remote.location,
            createdAt: created_at,
            updatedAt: remote.updated_at,
            color: remote.color ?? .yellow,
            reminderTriggers: remote.reminder_triggers ?? [],
            version: remote.version
        )
    }
    
    func getUpdateFields(_ event: EventRemote) {
        self.userId = event.user_id
        self.title = event.title
        self.notes = event.notes
        self.startDate = event.start_datetime
        self.endDate = event.end_datetime
        self.location = event.location
        self.isRecurring = event.is_recurring
        self.createdAt = event.created_at ?? Date()
        self.updatedAt = event.updated_at
        self.color = event.color ?? .yellow
        self.reminderTriggersArray = event.reminder_triggers ?? []
        self.deletedAt = event.deleted_at
        self.needsSync = false
        self.version = event.version
    }
    
    func getUpdateFields(_ event: Event) {
        self.userId = event.userId
        self.title = event.title
        self.notes = event.notes
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.location = event.location
        self.isRecurring = event.isRecurring
        self.createdAt = event.createdAt
        self.updatedAt = event.updatedAt
        self.color = event.color
        self.reminderTriggersArray = event.reminderTriggers ?? []
        self.deletedAt = event.deletedAt
        self.needsSync = true
        self.version = event.version
    }
    
    func getUpdateFields(_ local: EventLocal) {
        self.userId = local.userId
        self.title = local.title
        self.notes = local.notes
        self.startDate = local.startDate
        self.endDate = local.endDate
        self.location = local.location
        self.isRecurring = local.isRecurring
        self.createdAt = local.createdAt
        self.updatedAt = local.updatedAt
        self.color = local.color
        self.reminderTriggers = local.reminderTriggers
        self.deletedAt = local.deletedAt
        self.needsSync = true
        self.version = local.version
    }
}
