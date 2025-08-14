//
//  TaskEditorService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

protocol TaskEditorService {
    func upsert(_ input: AddTaskInput) async throws
    func delete(_ input: EditTaskInput, id: UUID) async throws
}

// DTOs decouple UI from domain defaults/validation
struct AddTaskInput {
    var id: UUID
    var userId: UUID?
    var title: String
    var notes: String?
    var dueDate: Date?
    var isCompleted: Bool
    var priority: UserTaskPriority
    var parentEventId: UUID?
    var tags: [Tag]
    var reminderTriggers: [ReminderTrigger]?
    var deleteAt: Date?
}

typealias EditTaskInput = AddTaskInput
