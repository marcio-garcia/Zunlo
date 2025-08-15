//
//  TaskInboxViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI
import FlowNavigator
import MiniSignalEye

class UserTaskInboxViewModel: ObservableObject {
    @Published var state: ViewState = .loading
    @Published var completeTasks: [UserTask] = []
    @Published var incompleteTasks: [UserTask] = []
    @Published var tags: [Tag] = []

    let taskRepo: UserTaskRepository
    var tasks: [UserTask] = []
    
    init(taskRepo: UserTaskRepository) {
        self.taskRepo = taskRepo
        observeTaskRepo()
    }
    
    func observeTaskRepo() {
        self.taskRepo.lastTaskAction.observe(owner: self, fireNow: false) { [weak self] action in
            if case .fetch(let tasks) = action {
                guard let self else { return }
                self.tasks = tasks
                self.completeTasks = tasks.filter { $0.deletedAt == nil && $0.isCompleted }
                self.incompleteTasks = tasks.filter { $0.deletedAt == nil && !$0.isCompleted }
                self.state = .loaded
            }
        }
}

    func fetchTasks() async {
        do {
            let taskFetcher = UserTaskFetcher(repo: taskRepo)
            let _ = try await taskFetcher.fetchTasks()
        } catch {
            await MainActor.run {
                state = .error(error.localizedDescription)
            }
        }
    }

    func fetchTags() async {
        do {
            let taskFetcher = UserTaskFetcher(repo: taskRepo)
            let tags = try await taskFetcher.fetchAllUniqueTags()
            let tagObjects = tags.map {
                Tag(id: UUID(), text: $0, color: Theme.highlightColor(for: $0), selected: false)
            }
            await MainActor.run {
                self.tags = tagObjects
            }
        } catch {
            await MainActor.run {
                state = .error(error.localizedDescription)
            }
        }
    }
    
    func filter() async  {
        do {
            let taskFetcher = UserTaskFetcher(repo: taskRepo)
            let selectedTags = tags.filter({ $0.selected })
            let filter = selectedTags.isEmpty ? nil : selectedTags.map({ $0.text })
            let taskFilter = TaskFilter(tags: filter)
            let _ = try await taskFetcher.fetchTasks(filteredBy: taskFilter)
        } catch {
            await MainActor.run {
                state = .error(error.localizedDescription)
            }
        }
    }
    
    func toggleCompletion(for task: UserTask) {
        var updated = task
        updated.isCompleted.toggle()
        
        Task {
            let taskEditor = TaskEditor(repo: taskRepo)
            try? await taskEditor.upsert(makeInput(task: updated))
            await fetchTasks()
        }
    }
    
    private func makeInput(task: UserTask) -> AddTaskInput {
        AddTaskInput(
            id: task.id,
            userId: task.userId,
            title: task.title,
            notes: task.notes,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted,
            priority: task.priority,
            parentEventId: task.parentEventId,
            tags: task.tags,
            reminderTriggers: task.reminderTriggers,
            deleteAt: task.deletedAt
        )
    }
}
