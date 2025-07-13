//
//  TaskInboxViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI

class UserTaskInboxViewModel: ObservableObject {
    @Published var state: ViewState = .loading
    @Published var tasks: [UserTask] = []
    @Published var showAddSheet: Bool = false

    let repository: UserTaskRepository

    init(repository: UserTaskRepository) {
        self.repository = repository
    }

    var unscheduledTasks: [UserTask] {
        tasks.filter { !$0.isCompleted && $0.scheduledDate == nil }
    }

    func fetchTasks() async {
        do {
            try await repository.fetchAll()
            await MainActor.run {
                tasks = repository.tasks.value
                state = unscheduledTasks.isEmpty ? .empty : .loaded
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
