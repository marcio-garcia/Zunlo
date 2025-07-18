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

    let repository: UserTaskRepository
    var tasks: [UserTask] = []

    init(repository: UserTaskRepository) {
        self.repository = repository
        self.repository.tasks.observe(owner: self, fireNow: false) { [weak self] tasks in
            guard let self else { return }
            self.tasks = tasks
            self.completeTasks = tasks.filter { $0.isCompleted }
            self.incompleteTasks = tasks.filter { !$0.isCompleted }
//            self?.state = self?.unscheduledTasks.isEmpty ? .empty : .loaded
            self.state = .loaded
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

    func toggleCompletion(for task: UserTask) {
        var updated = task
        updated.isCompleted.toggle()
        Task {
            try? await repository.update(updated)
            await fetchTasks()
        }
    }
}
