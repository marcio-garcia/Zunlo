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

    func upsert(input: AddTaskInput) async throws {
        try await repo.upsert(makeUserTask(input))
    }
    
    func upsert(task: UserTask) async throws {
        try await repo.upsert(task)
    }

    func delete(task: UserTask) async throws {
        try await repo.delete(task)
    }
    
    private func makeUserTask(_ input: AddTaskInput) -> UserTask {
        let now = Date()
        let task = UserTask(
            id: input.id,
            userId: input.userId,
            title: input.title,
            notes: input.notes.nilIfEmpty,
            isCompleted: input.isCompleted,
            createdAt: now,
            updatedAt: now,
            dueDate: input.dueDate,
            priority: input.priority,
            parentEventId: input.parentEventId,
            tags: input.tags,
            reminderTriggers: input.reminderTriggers,
            version: input.version
        )
        return task
    }
}
