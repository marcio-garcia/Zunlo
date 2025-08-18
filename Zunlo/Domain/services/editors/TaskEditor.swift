//
//  TaskEditor.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation
import MiniSignalEye

final class TaskEditor: TaskEditorService {
    private let repo: UserTaskRepository
    private let clock: () -> Date
        
    init(repo: UserTaskRepository, clock: @escaping () -> Date = Date.init) {
        self.repo = repo
        self.clock = clock
    }

    func upsert(_ input: AddTaskInput) async throws {
        try await repo.upsert(makeUserTask(input, id: nil))
    }

    func delete(_ input: EditTaskInput, id: UUID) async throws {
        try await repo.delete(makeUserTask(input, id: id))
    }
    
    private func makeUserTask(_ input: AddTaskInput, id: UUID?) -> UserTask {
        let now = Date()
        let task = UserTask(
            id: id ?? UUID(),
            userId: nil, // Backend fills this
            title: input.title,
            notes: input.notes.nilIfEmpty,
            isCompleted: input.isCompleted,
            createdAt: now,
            updatedAt: now,
            dueDate: input.dueDate,
            priority: input.priority,
            parentEventId: nil,
            tags: input.tags,
            reminderTriggers: input.reminderTriggers,
            version: input.version
        )
        return task
    }
}
