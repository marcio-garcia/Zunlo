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
    @Published var allUniqueTags: [String] = []

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
    private let editor: TaskEditorService
    var createdAt: Date?
    
    var id: String {
        switch mode {
        case .add: return "add"
        case .edit(let task): return task.id == nil ? "edit-nil" : "edit-\(task.id!)"
        }
    }

    init(mode: Mode, editor: TaskEditorService) {
        self.mode = mode
        self.editor = editor
        loadFields()
    }

    func navigationTitle() -> String {
        switch mode {
        case .add: return String(localized: "Add Task")
        case .edit: return String(localized: "Edit Task")
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

        Task {
            do {
                switch mode {
                case .add:
                    try await editor.add(makeInput())
                case .edit:
                    try await editor.update(makeInput(), id: id!)
                }
                await MainActor.run {
                    self.isProcessing = false
                    completion(.success(()))
                }
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
            tags = task.tags
            reminderTriggers = task.reminderTriggers ?? []
        }
        Task {
            await fetchAllUniqueTags()
        }
    }
    
    func loadFilteredTasks() async {
//        let filter = TaskFilter(tags: selectedTags)
//        tasks = try await repository.fetchTasks(filteredBy: filter)
    }
    
    func fetchAllUniqueTags() async {
        do {
            let tags = try await editor.fetchAllUniqueTags()
            await MainActor.run { allUniqueTags = tags }
        } catch {
            await MainActor.run { allUniqueTags = [] }
        }
    }
    
    @MainActor
    func delete() async {
        guard !isProcessing else { return }
        isProcessing = true
        
        if case .edit(let userTask) = mode {
            do {
                try await editor.delete(makeInput(), id: userTask.id!)
                isProcessing = false
            } catch {
                print("error: \(error.localizedDescription)")
                self.isProcessing = false
            }
        }
    }
    
    private func makeInput() -> AddTaskInput {
        AddTaskInput(
            title: title,
            notes: notes,
            dueDate: dueDate,
            isCompleted: isCompleted,
            priority: priority,
            tags: tags,
            reminderTriggers: reminderTriggers
        )
    }
}
