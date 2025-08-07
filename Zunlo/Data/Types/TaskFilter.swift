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
}
