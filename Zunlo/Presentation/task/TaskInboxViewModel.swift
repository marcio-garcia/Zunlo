//
//  TaskInboxViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI
import FlowNavigator
import MiniSignalEye
import GlowUI

class UserTaskInboxViewModel: ObservableObject {
    @Published var state: ViewState = .loading
    @Published var tags: [Tag] = []
    
    var completeTasks: [UserTask] = []
    var incompleteTasks: [UserTask] = []

    let taskRepo: UserTaskRepository
    var tasks: [UserTask] = []
    
    init(taskRepo: UserTaskRepository) {
        self.taskRepo = taskRepo
    }
    
    func fetchTasks() async {
        do {
            let taskFetcher = UserTaskFetcher(repo: taskRepo)
            let tasks = try await taskFetcher.fetchTasks()
            
            handleTasks(tasks)
            
            guard !tasks.isEmpty else {
                await MainActor.run { state = .empty }
                return
            }
            
            try await fetchTags()
            await MainActor.run { state = .loaded }
            
        } catch {
            await MainActor.run {
                state = .error(error.localizedDescription)
            }
        }
    }

    func fetchTags() async throws {
        let taskFetcher = UserTaskFetcher(repo: taskRepo)
        let tags = try await taskFetcher.fetchAllUniqueTags()
        
        let tagObjects = tags.map {
            Tag(id: UUID(), text: $0, color: Theme.highlightColor(for: $0), selected: false)
        }
        
        await MainActor.run {
            self.tags = tagObjects
        }
    }
    
    func filter() async  {
        do {
            let taskFetcher = UserTaskFetcher(repo: taskRepo)
            let selectedTags = tags.filter({ $0.selected })
            let filter = selectedTags.isEmpty ? nil : selectedTags.map({ $0.text })
            let taskFilter = TaskFilter(tags: filter)
            let tasks = try await taskFetcher.fetchTasks(filteredBy: taskFilter)
            handleTasks(tasks)
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
            try? await taskEditor.upsert(input: makeInput(task: updated))
            await fetchTasks()
        }
    }
    
    private func handleTasks(_ tasks: [UserTask]) {
        self.tasks = tasks
        self.completeTasks = tasks.filter { $0.deletedAt == nil && $0.isCompleted }
        self.incompleteTasks = tasks.filter { $0.deletedAt == nil && !$0.isCompleted }
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
