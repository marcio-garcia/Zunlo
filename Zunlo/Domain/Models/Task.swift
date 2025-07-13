//
//  Task.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation
import RealmSwift

enum UserTaskPriority: String, CaseIterable, Codable {
    case low, medium, high
}

struct UserTask: Identifiable, Codable, Hashable {
    let id: UUID?
    let userId: UUID?
    var title: String
    var notes: String?
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date
    var scheduledDate: Date?
    var dueDate: Date?
    var priority: UserTaskPriority?
    var parentEventId: UUID?
    var tags: [String]
    
    internal init(id: UUID?, userId: UUID? = nil, title: String, notes: String? = nil, isCompleted: Bool, createdAt: Date, updatedAt: Date, scheduledDate: Date? = nil, dueDate: Date? = nil, priority: UserTaskPriority? = nil, parentEventId: UUID? = nil, tags: [String]) {
        self.id = id
        self.userId = userId
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.scheduledDate = scheduledDate
        self.dueDate = dueDate
        self.priority = priority
        self.parentEventId = parentEventId
        self.tags = tags
    }
}
