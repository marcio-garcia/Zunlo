//
//  TaskFilter.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/26/25.
//

import Foundation

public struct TaskFilter {
    var tags: [String]?
    var priority: UserTaskPriorityLocal?
    var isCompleted: Bool?
    var dueDateRange: Range<Date>?
    var untilDueDate: Date?
    var deleted: Bool?
    
    init(
        tags: [String]? = nil,
        priority: UserTaskPriorityLocal? = nil,
        isCompleted: Bool? = nil,
        dueDateRange: Range<Date>? = nil,
        untilDueDate: Date? = nil,
        deleted: Bool? = nil
    ) {
        self.tags = tags
        self.priority = priority
        self.isCompleted = isCompleted
        self.dueDateRange = dueDateRange
        self.untilDueDate = untilDueDate
        self.deleted = deleted
    }
}
