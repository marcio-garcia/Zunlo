//
//  TaskInboxViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI
import FlowNavigator

class UserTaskInboxViewModel: ObservableObject {
    @Published var state: ViewState = .loading
    @Published var completeTasks: [UserTask] = []
    @Published var incompleteTasks: [UserTask] = []
    @Published var tags: [Tag] = []

    let taskFetcher: UserTaskFetcherService
    let taskEditor: TaskEditorService
    var tasks: [UserTask] = []
    
    init(taskFetcher: UserTaskFetcherService, taskEditor: TaskEditorService) {
        self.taskFetcher = taskFetcher
        self.taskEditor = taskEditor
//        self.repository.tasks.observe(owner: self, fireNow: false) { [weak self] tasks in
//            guard let self else { return }
//            self.tasks = tasks
//            self.completeTasks = tasks.filter { $0.isCompleted }
//            self.incompleteTasks = tasks.filter { !$0.isCompleted }
//            self.state = .loaded
//        }
    }

    func fetchTasks() async {
        do {
            let tasks = try await taskFetcher.fetchTasks()
            await MainActor.run {
                self.tasks = tasks
                self.completeTasks = tasks.filter { $0.isCompleted }
                self.incompleteTasks = tasks.filter { !$0.isCompleted }
                self.state = .loaded
            }
        } catch {
            await MainActor.run {
                state = .error(error.localizedDescription)
            }
        }
    }

    func fetchTags() async {
        do {
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
            let selectedTags = tags.filter({ $0.selected })
            let filter = selectedTags.isEmpty ? nil : selectedTags.map({ $0.text })
            let taskFilter = TaskFilter(tags: filter)
            let tasks = try await taskFetcher.fetchTasks(filteredBy: taskFilter)
            await MainActor.run {
                self.tasks = tasks
                self.completeTasks = tasks.filter { $0.isCompleted }
                self.incompleteTasks = tasks.filter { !$0.isCompleted }
                self.state = .loaded
            }
        } catch {
            await MainActor.run {
                state = .error(error.localizedDescription)
            }
        }
    }
    
    func toggleCompletion(for task: UserTask) {
        guard let id = task.id else { return }
        var updated = task
        updated.isCompleted.toggle()
        
        Task {
            try? await taskEditor.update(makeInput(task: updated), id: id)
            await fetchTasks()
        }
    }
    
    private func makeInput(task: UserTask) -> AddTaskInput {
        AddTaskInput(
            title: task.title,
            notes: task.notes,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted,
            priority: task.priority,
            tags: task.tags,
            reminderTriggers: task.reminderTriggers
        )
    }
}
