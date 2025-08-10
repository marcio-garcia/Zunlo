//
//  TaskEditorService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

protocol TaskEditorService {
    @discardableResult
    func add(_ input: AddTaskInput) async throws -> UserTask
    func update(_ input: EditTaskInput, id: UUID) async throws
    func delete(_ input: EditTaskInput, id: UUID) async throws
}

// DTOs decouple UI from domain defaults/validation
struct AddTaskInput {
    var title: String
    var notes: String?
    var dueDate: Date?
    var isCompleted: Bool
    var priority: UserTaskPriority
    var tags: [Tag]
    var reminderTriggers: [ReminderTrigger]?
}

typealias EditTaskInput = AddTaskInput
