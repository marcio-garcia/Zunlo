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
    let editableTaskProvider: (() -> UserTask?)?
    let onAddEditTaskViewDismiss: (() -> Void)?
    
    internal init(
        viewID: UUID,
        nav: AppNav,
        editableTaskProvider: (() -> UserTask?)? = nil,
        onAddEditTaskViewDismiss: (() -> Void)? = nil
    ) {
        self.viewID = viewID
        self.nav = nav
        self.editableTaskProvider = editableTaskProvider
        self.onAddEditTaskViewDismiss = onAddEditTaskViewDismiss
    }

    func buildTaskInboxView() -> AnyView {
        AnyView(
            TaskInboxView(repository: AppState.shared.userTaskRepository!)
                .environmentObject(nav)
        )
    }

    func buildAddTaskView() -> AnyView {
        AnyView(
            AddEditTaskView(
                viewModel: AddEditTaskViewModel(
                    mode: .add,
                    taskFetcher: UserTaskFetcher(repo: AppState.shared.userTaskRepository!),
                    taskEditor: TaskEditor(repo: AppState.shared.userTaskRepository!)
                ),
                onDismiss: {
                    onAddEditTaskViewDismiss?()
                }
            )
            .environmentObject(nav)
        )
    }

    func buildEditTaskView(id: UUID) -> AnyView {
        guard let task = editableTaskProvider?(), task.id == id else {
            return AnyView(FallbackView(message: "Could not edit task.", nav: nav, viewID: viewID))
        }
        return AnyView(
            AddEditTaskView(
                viewModel: AddEditTaskViewModel(
                    mode: .edit(task),
                    taskFetcher: UserTaskFetcher(repo: AppState.shared.userTaskRepository!),
                    taskEditor: TaskEditor(repo: AppState.shared.userTaskRepository!)
                ),
                onDismiss: {
                    onAddEditTaskViewDismiss?()
                }
            )
            .environmentObject(nav)
        )
    }

    func buildTaskDetailView(id: UUID) -> AnyView {
        // You can add logic to fetch the task or fallback
        return AnyView(Text("Task Detail for \(id)"))
    }

    func buildDeleteTaskConfirmationView(onOptionSelected: @escaping (String) -> Void) -> AnyView {
//        guard let viewModel = addEditTaskViewModel else {
//            return AnyView(FallbackView(message: "Could not edit task.", nav: nav, viewID: viewID))
//        }
        return AnyView(
            Group {
                Button("Delete this task") {
                    onOptionSelected("delete")
//                    viewModel.delete()
                }
                Button("Cancel", role: .cancel) {
//                    nav.dismissDialog(for: viewID)
                    onOptionSelected("cancel")
                }
            }
        )
    }
}
