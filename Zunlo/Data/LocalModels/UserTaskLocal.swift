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
    @Persisted var dueDate: Date?
    @Persisted var priority: UserTaskPriorityLocal = .medium
    @Persisted var parentEventId: UUID?
    @Persisted var tags: List<String>
    @Persisted var reminderTriggers: List<ReminderTriggerLocal>

    // NEW
    @Persisted var deletedAt: Date?
    @Persisted var needsSync: Bool = false
    
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
    
    convenience init(remote: UserTaskRemote) {
        self.init()
        self.id = remote.id
        self.userId = remote.userId
        self.title = remote.title
        self.notes = remote.notes
        self.isCompleted = remote.isCompleted
        self.createdAt = remote.createdAt ?? Date()
        self.updatedAt = remote.updatedAt
        self.dueDate = remote.dueDate
        self.priority = UserTaskPriorityLocal.fromDomain(domain: remote.priority)
        self.parentEventId = remote.parentEventId
        self.tags.removeAll()
        self.tags.append(objectsIn: remote.tags)
        self.reminderTriggersArray = remote.reminderTriggers ?? []
        self.deletedAt = remote.deletedAt
        self.needsSync = false
    }

    convenience init(domain: UserTask) {
        self.init()
        self.id = domain.id
        self.userId = domain.userId
        self.title = domain.title
        self.notes = domain.notes
        self.isCompleted = domain.isCompleted
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
        self.dueDate = domain.dueDate
        self.priority = UserTaskPriorityLocal.fromDomain(domain: domain.priority)
        self.parentEventId = domain.parentEventId
        self.tags.removeAll()
        self.tags.append(objectsIn: domain.tags.map({ $0.text }))
        self.reminderTriggersArray = domain.reminderTriggers ?? []
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
            dueDate: dueDate,
            priority: priority.toDomain(),
            parentEventId: parentEventId,
            tags: Array(tags).map({
                Tag(id: UUID(),
                    text: $0,
                    color: Theme.highlightColor(for: $0),
                    selected: false)
            }),
            reminderTriggers: reminderTriggersArray,
            deletedAt: deletedAt,
            needsSync: needsSync
        )
    }
    
    func getUpdateFields(remote: UserTaskRemote) {
        self.title = remote.title
        self.notes = remote.notes
        self.isCompleted = remote.isCompleted
        self.updatedAt = remote.updatedAt
        self.dueDate = remote.dueDate
        self.priority = UserTaskPriorityLocal.fromDomain(domain: remote.priority)
        self.parentEventId = remote.parentEventId
        self.tags.removeAll()
        self.tags.append(objectsIn: remote.tags)
        self.reminderTriggersArray = remote.reminderTriggers ?? []
        self.deletedAt = remote.deletedAt
        self.needsSync = false
    }
    
    func getUpdateFields(domain: UserTask) {
        self.title = domain.title
        self.notes = domain.notes
        self.isCompleted = domain.isCompleted
        self.updatedAt = Date()
        self.dueDate = domain.dueDate
        self.priority = UserTaskPriorityLocal.fromDomain(domain: domain.priority)
        self.parentEventId = domain.parentEventId
        self.tags.removeAll()
        self.tags.append(objectsIn: domain.tags.map({ $0.text }))
        self.reminderTriggersArray = domain.reminderTriggers ?? []
        self.deletedAt = domain.deletedAt
        self.needsSync = true
    }
}

enum UserTaskPriorityLocal: Int, Codable, PersistableEnum {
    case low, medium, high
    
    func toDomain() -> UserTaskPriority {
        switch self {
        case .low: return UserTaskPriority.low
        case .medium: return UserTaskPriority.medium
        case .high: return UserTaskPriority.high
        }
    }
    
    static func fromDomain(domain: UserTaskPriority) -> UserTaskPriorityLocal {
        switch domain {
        case .low: return UserTaskPriorityLocal.low
        case .medium: return UserTaskPriorityLocal.medium
        case .high: return UserTaskPriorityLocal.high
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
