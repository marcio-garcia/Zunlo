//
//  TaskFilter.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/26/25.
//

import Foundation

struct TaskFilter {
    var tags: [String]?
    var userId: UUID?
    var priority: UserTaskPriorityLocal?
    var isCompleted: Bool?
    var dueDateRange: ClosedRange<Date>?
    var untilDueDate: Date?
    var deleted: Bool?
    
    init(
        tags: [String]? = nil,
        userId: UUID? = nil,
        priority: UserTaskPriorityLocal? = nil,
        isCompleted: Bool? = nil,
        dueDateRange: ClosedRange<Date>? = nil,
        untilDueDate: Date? = nil,
        deleted: Bool? = nil
    ) {
        self.tags = tags
        self.userId = userId
        self.priority = priority
        self.isCompleted = isCompleted
        self.dueDateRange = dueDateRange
        self.untilDueDate = untilDueDate
        self.deleted = deleted
    }
}
