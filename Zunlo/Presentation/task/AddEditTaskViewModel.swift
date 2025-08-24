//
//  AddEditTaskViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI
import MiniSignalEye

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
    private let taskFetcher: UserTaskFetcherService
    private let taskEditor: TaskEditorService
    var createdAt: Date?
    var onTaskChanged: Observable<UserTask?>?
    
    @MainActor let errorHandler = ErrorHandler()
    
    var id: String {
        switch mode {
        case .add: return "add"
        case .edit(let task): return "edit-\(task.id)"
        }
    }

    init(mode: Mode, taskFetcher: UserTaskFetcherService, taskEditor: TaskEditorService) {
        self.mode = mode
        self.taskFetcher = taskFetcher
        self.taskEditor = taskEditor
        
        switch mode {
        case .add: self.onTaskChanged = Observable(nil)
        case .edit(let task): self.onTaskChanged = Observable(task)
        }
        
        loadFields()
    }

    func navigationTitle() -> String {
        switch mode {
        case .add: return String(localized: "Add task")
        case .edit: return String(localized: "Edit task")
        }
    }

    func save() async -> Bool {
        guard !isProcessing, !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        await MainActor.run { isProcessing = true }

        do {
            try await taskEditor.upsert(input: makeInput(mode: mode))
            await MainActor.run { self.isProcessing = false }
            return true
        } catch {
            await MainActor.run { self.isProcessing = false }
            await errorHandler.handle(error)
            return false
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
            let tags = try await taskFetcher.fetchAllUniqueTags()
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
                try await taskEditor.delete(task: userTask)
                isProcessing = false
            } catch {
                self.isProcessing = false
                errorHandler.handle(error)
            }
        }
    }
    
    private func makeInput(mode: Mode) -> AddTaskInput {
        var id: UUID
        var userId: UUID?
        var parentEventId: UUID?
        
        switch mode {
        case .add:
            id = UUID()
            userId = nil
            parentEventId = nil
        case .edit(let task):
            id = task.id
            userId = task.userId
            parentEventId = task.parentEventId
        }
        
        return AddTaskInput(
            id: id,
            userId: userId,
            title: title,
            notes: notes,
            dueDate: dueDate,
            isCompleted: isCompleted,
            priority: priority,
            parentEventId: parentEventId,
            tags: tags,
            reminderTriggers: reminderTriggers,
            deleteAt: nil
        )
    }
}
