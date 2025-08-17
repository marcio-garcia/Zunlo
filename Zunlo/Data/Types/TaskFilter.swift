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
    
    init(
        tags: [String]? = nil,
        userId: UUID? = nil,
        priority: UserTaskPriorityLocal? = nil,
        isCompleted: Bool? = nil,
        dueDateRange: ClosedRange<Date>? = nil
    ) {
        self.tags = tags
        self.userId = userId
        self.priority = priority
        self.isCompleted = isCompleted
        self.dueDateRange = dueDateRange
    }
}
