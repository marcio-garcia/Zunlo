//
//  TaskViewFactory.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/7/25.
//

import SwiftUI
import FlowNavigator

struct TaskViewFactory: TaskViews {
    let viewID: UUID
    let nav: AppNav
    let repository: UserTaskRepository
    let editableTaskProvider: (() -> UserTask?)?
    let addEditTaskViewModel: AddEditTaskViewModel?

    internal init(
        viewID: UUID,
        nav: AppNav,
        repository: UserTaskRepository,
        editableTaskProvider: (() -> UserTask?)? = nil,
        addEditTaskViewModel: AddEditTaskViewModel? = nil
    ) {
        self.viewID = viewID
        self.nav = nav
        self.repository = repository
        self.editableTaskProvider = editableTaskProvider
        self.addEditTaskViewModel = addEditTaskViewModel
    }

    func buildTaskInboxView() -> AnyView {
        AnyView(TaskInboxView(repository: repository))
    }

    func buildAddTaskView() -> AnyView {
        AnyView(
            AddEditTaskView(
                viewModel: AddEditTaskViewModel(mode: .add, repository: repository),
                nav: nav
        ))
    }

    func buildEditTaskView(id: UUID) -> AnyView {
        guard let task = editableTaskProvider?(), task.id == id else {
            return AnyView(FallbackView(message: "Could not edit task.", nav: nav, viewID: viewID))
        }
        return AnyView(
            AddEditTaskView(
                viewModel: AddEditTaskViewModel(mode: .edit(task), repository: repository),
                nav: nav
        ))
    }

    func buildTaskDetailView(id: UUID) -> AnyView {
        // You can add logic to fetch the task or fallback
        return AnyView(Text("Task Detail for \(id)"))
    }

    func buildDeleteTaskConfirmationView() -> AnyView {
        guard let viewModel = addEditTaskViewModel else {
            return AnyView(FallbackView(message: "Could not edit task.", nav: nav, viewID: viewID))
        }
        return AnyView(
            Group {
                Button("Delete this event") {
                    viewModel.delete()
                }
                Button("Cancel", role: .cancel) {
                    nav.dismissDialog(for: viewID)
                }
            }
        )
    }
}
