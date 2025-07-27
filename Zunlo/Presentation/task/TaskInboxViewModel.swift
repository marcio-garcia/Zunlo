//
//  TaskInboxViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI

class UserTaskInboxViewModel: ObservableObject {
    @Published var state: ViewState = .loading
    @Published var completeTasks: [UserTask] = []
    @Published var incompleteTasks: [UserTask] = []
    @Published var showAddSheet: Bool = false
    @Published var tags: [Tag] = []

    let repository: UserTaskRepository
    var tasks: [UserTask] = []

    init(repository: UserTaskRepository) {
        self.repository = repository
        self.repository.tasks.observe(owner: self, fireNow: false) { [weak self] tasks in
            guard let self else { return }
            self.tasks = tasks
            self.completeTasks = tasks.filter { $0.isCompleted }
            self.incompleteTasks = tasks.filter { !$0.isCompleted }
            self.state = .loaded(referenceDate: Date())
        }
    }

    func fetchTasks() async {
        do {
            try await repository.fetchAll()
            await MainActor.run {
                tasks = repository.tasks.value
            }
        } catch {
            await MainActor.run {
                state = .error(error.localizedDescription)
            }
        }
    }

    func fetchTags() async {
        do {
            let tags = try await repository.fetchAllUniqueTags()
            let tagObjects = tags.map { Tag(text: $0, color: Theme.highlightColor(for: $0)) }
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
            try await repository.fetchTasks(filteredBy: taskFilter)
            await MainActor.run {
                tasks = repository.tasks.value
            }
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
            try? await repository.update(updated)
            await fetchTasks()
        }
    }
}
