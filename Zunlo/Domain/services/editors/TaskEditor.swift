//
//  TaskEditor.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

final class TaskEditor: TaskEditorService {
    private let repo: UserTaskRepository
    private let clock: () -> Date
    
    init(repo: UserTaskRepository, clock: @escaping () -> Date = Date.init) {
        self.repo = repo
        self.clock = clock
    }

    func add(_ input: AddTaskInput) async throws -> UserTask {
        return try await repo.save(makeUserTask(input, id: nil))
    }
    
    func update(_ input: EditTaskInput, id: UUID) async throws {
        return try await repo.update(makeUserTask(input, id: id))
    }
    
    func delete(_ input: EditTaskInput, id: UUID) async throws {
        try await repo.delete(makeUserTask(input, id: id))
    }
    
    func fetchAllUniqueTags() async throws -> [String] {
        try await repo.fetchAllUniqueTags()
    }
    
    private func makeUserTask(_ input: AddTaskInput, id: UUID?) -> UserTask {
        let now = Date()
        let task = UserTask(
            id: id,
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
            reminderTriggers: input.reminderTriggers
        )
        return task
    }
}
