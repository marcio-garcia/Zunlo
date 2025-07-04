//
//  EventLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import Foundation
import SwiftData

@Model
final class EventLocal: Identifiable {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var title: String
    var createdAt: Date
    var dueDate: Date
    var recurrence: RecurrenceRule? = RecurrenceRule.none
    var exceptions: [Date] = []
    var isComplete: Bool

    init(id: UUID,
         userId: UUID,
         title: String,
         createdAt: Date,
         dueDate: Date,
         recurrence: RecurrenceRule? = RecurrenceRule.none,
         exceptions: [Date] = [],
         isComplete: Bool) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.isComplete = isComplete
        self.recurrence = recurrence
        self.exceptions = exceptions
        self.userId = userId
    }
}
