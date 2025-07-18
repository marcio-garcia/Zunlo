//
//  UserTaskLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation
import RealmSwift

class UserTaskLocal: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted var userId: UUID?
    @Persisted var title: String = ""
    @Persisted var notes: String?
    @Persisted var isCompleted: Bool = false
    @Persisted var createdAt: Date = Date()
    @Persisted var updatedAt: Date = Date()
    @Persisted var scheduledDate: Date?
    @Persisted var dueDate: Date?
    @Persisted var priority: UserTaskPriorityLocal?
    @Persisted var parentEventId: UUID?
    @Persisted var tags: List<String>
    @Persisted var reminderTriggers: List<ReminderTriggerLocal>

    var tagsArray: [String] {
        get { Array(tags) }
        set {
            tags.removeAll()
            tags.append(objectsIn: newValue)
        }
    }
    
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
    
    convenience init(from remote: UserTaskRemote) {
        self.init()
        self.id = remote.id ?? UUID()
        self.userId = remote.user_id
        self.title = remote.title
        self.notes = remote.notes
        self.isCompleted = remote.is_completed
        self.createdAt = remote.created_at ?? Date()
        self.updatedAt = remote.updated_at
        self.scheduledDate = remote.scheduled_date
        self.dueDate = remote.due_date
        self.priority = UserTaskPriorityLocal.fromDomain(domain: remote.priority)
        self.parentEventId = remote.parent_event_id
        self.tags.append(objectsIn: remote.tags)
        self.reminderTriggersArray = remote.reminder_triggers ?? []
    }

    func toDomain() -> UserTask {
        UserTask(
            id: id,
            userId: userId,
            title: title,
            notes: notes,
            isCompleted: isCompleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            scheduledDate: scheduledDate,
            dueDate: dueDate,
            priority: priority?.toDomain(),
            parentEventId: parentEventId,
            tags: Array(tags),
            reminderTriggers: reminderTriggersArray
        )
    }
    
    func getUpdateFields(remote: UserTaskRemote) {
        self.title = remote.title
        self.notes = remote.notes
        self.isCompleted = remote.is_completed
        self.updatedAt = remote.updated_at
        self.scheduledDate = remote.scheduled_date
        self.dueDate = remote.due_date
        self.priority = UserTaskPriorityLocal.fromDomain(domain: remote.priority)
        self.parentEventId = remote.parent_event_id
        self.tags.append(objectsIn: remote.tags)
        self.reminderTriggersArray = remote.reminder_triggers ?? []
    }
}

enum UserTaskPriorityLocal: String, Codable, PersistableEnum {
    case low, medium, high
    
    func toDomain() -> UserTaskPriority {
        switch self {
        case .low: return UserTaskPriority.low
        case .medium: return UserTaskPriority.medium
        case .high: return UserTaskPriority.high
        }
    }
    
    static func fromDomain(domain: UserTaskPriority?) -> UserTaskPriorityLocal? {
        switch domain {
        case .low: return UserTaskPriorityLocal.low
        case .medium: return UserTaskPriorityLocal.medium
        case .high: return UserTaskPriorityLocal.high
        case .none: return nil
        }
    }
}

final class ReminderTriggerLocal: EmbeddedObject, ObjectKeyIdentifiable {
    @Persisted var timeBeforeDue: Double
    @Persisted var message: String?

    convenience init(timeBeforeDue: TimeInterval, message: String?) {
        self.init()
        self.timeBeforeDue = timeBeforeDue
        self.message = message
    }

    var toDomain: ReminderTrigger {
        ReminderTrigger(timeBeforeDue: timeBeforeDue, message: message)
    }
}
