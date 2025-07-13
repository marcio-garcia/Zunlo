//
//  AddEditTaskViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI

final class AddEditTaskViewModel: ObservableObject, Identifiable {
    enum Mode {
        case add
        case edit(UserTask)
    }

    @Published var title: String = ""
    @Published var notes: String = ""
    @Published var scheduledDate: Date?
    @Published var dueDate: Date?
    @Published var isCompleted: Bool = false
    @Published var priority: UserTaskPriority = .medium
    @Published var tags: String = ""
    @Published var isSaving = false

    let mode: Mode
    let repository: UserTaskRepository

    var id: String {
        switch mode {
        case .add: return "add"
        case .edit(let task):
            return task.id == nil ? "edit-nil" : "edit-\(task.id!)"
        }
    }

    init(mode: Mode, repository: UserTaskRepository) {
        self.mode = mode
        self.repository = repository
        loadFields()
    }

    func navigationTitle() -> String {
        switch mode {
        case .add: return "Add Task"
        case .edit: return "Edit Task"
        }
    }

    func save(completion: @escaping (Result<Void, Error>) -> Void) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSaving = true

        let now = Date()
        let tagArray = tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var id: UUID? = nil
        if case .edit(let userTask) = mode {
            id = userTask.id
        }
        
        let task = UserTask(
            id: id,
            userId: nil, // Backend fills this
            title: title,
            notes: notes.isEmpty ? nil : notes,
            isCompleted: isCompleted,
            createdAt: now,
            updatedAt: now,
            scheduledDate: scheduledDate,
            dueDate: dueDate,
            priority: priority,
            parentEventId: nil,
            tags: tagArray
        )

        Task {
            do {
                switch mode {
                case .add:
                    try await repository.save(task)
                case .edit:
                    try await repository.update(task)
                }
                isSaving = false
                completion(.success(()))
            } catch {
                isSaving = false
                completion(.failure(error))
            }
        }
    }

    private func loadFields() {
        if case .edit(let task) = mode {
            title = task.title
            notes = task.notes ?? ""
            isCompleted = task.isCompleted
            scheduledDate = task.scheduledDate
            dueDate = task.dueDate
            priority = task.priority ?? .medium
            tags = task.tags.joined(separator: ", ")
        }
    }
}
