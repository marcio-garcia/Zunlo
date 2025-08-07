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
    @Published var dueDate: Date?
    @Published var isCompleted: Bool = false
    @Published var priority: UserTaskPriority = .medium
    @Published var tags: [Tag] = []
    @Published var isProcessing = false
    @Published var reminderTriggers: [ReminderTrigger] = []
    
    @Published var selectedTags: [String] = []

    @Published var hasDueDate: Bool = false {
        didSet {
            if !hasDueDate {
                dueDate = nil
            } else if dueDate == nil {
                dueDate = Date()
            }
        }
    }
    
    let mode: Mode
    let repository: UserTaskRepository
    var createdAt: Date?
    
    var onDelete: (() -> Void)?
    
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
        guard !isProcessing, !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isProcessing = true

        let now = Date()
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
            createdAt: createdAt ?? now,
            updatedAt: now,
            dueDate: dueDate,
            priority: priority,
            parentEventId: nil,
            tags: tags.map({ $0.text }),
            reminderTriggers: reminderTriggers
        )

        Task {
            do {
                switch mode {
                case .add:
                    try await repository.save(task)
                case .edit:
                    try await repository.update(task)
                }
                await MainActor.run {
                    self.isProcessing = false
                }
                completion(.success(()))
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                }
                completion(.failure(error))
            }
        }
    }

    private func loadFields() {
        if case .edit(let task) = mode {
            title = task.title
            notes = task.notes ?? ""
            isCompleted = task.isCompleted
            dueDate = task.dueDate
            hasDueDate = task.dueDate != nil
            priority = task.priority
            createdAt = task.createdAt
            tags = task.tags.map({ text in
                return Tag(id: UUID(), text: text, color: Theme.light.accent)
            })
            reminderTriggers = task.reminderTriggers ?? []
        }
    }
    
    func loadFilteredTasks() async {
//        let filter = TaskFilter(tags: selectedTags)
//        tasks = try await repository.fetchTasks(filteredBy: filter)
    }
    
    func fetchAllTags() async throws -> [String] {
        try await repository.fetchAllUniqueTags()
    }
    
    func delete() {
        guard !isProcessing else { return }
        isProcessing = true
        
        if case .edit(let userTask) = mode {
            Task {
                do {
                    try await repository.delete(userTask)
                    await MainActor.run { self.isProcessing = false }
                    onDelete?()
                } catch {
                    print("error: \(error.localizedDescription)")
                    await MainActor.run { self.isProcessing = false }
                }
            }
        }
    }
}
