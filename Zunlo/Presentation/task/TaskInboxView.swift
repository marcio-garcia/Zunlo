//
//  TaskInboxView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI
import FlowNavigator

struct TaskInboxView: View {
    @State private var viewID = UUID()
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var nav: AppNavigationManager
    @StateObject private var viewModel: UserTaskInboxViewModel
    @State private var editableUserTask: UserTask?
    @State private var tagEditorHeight: CGFloat = .zero
    
    init(repository: UserTaskRepository) {
        _viewModel = StateObject(wrappedValue: UserTaskInboxViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView("Loading your tasks...")

                case .empty:
                    EmptyInboxView {
                        nav.showSheet(.addTask, for: viewID)
                    }

                case .error(let message):
                    Text("Error: \(message)")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()

                case .loaded:
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            TagEditorView(tags: $viewModel.tags, height: $tagEditorHeight, readOnly: true) { tag in
                                Task { await viewModel.filter() }
                            }
                            .frame(height: tagEditorHeight)
                            .animation(.default, value: tagEditorHeight)
                            
                            Divider()
                            
                            ForEach(viewModel.incompleteTasks) { task in
                                TaskRow(task: task) {
                                    viewModel.toggleCompletion(for: task)
                                } onTap: {
                                    guard let id = task.id else { return }
                                    editableUserTask = task
                                    nav.showSheet(.editTask(id), for: viewID)
                                }
                            }
                            
                            Divider()
                            
                            ForEach(viewModel.completeTasks) { task in
                                TaskRow(task: task) {
                                    viewModel.toggleCompletion(for: task)
                                } onTap: {
                                    guard let id = task.id else { return }
                                    editableUserTask = task
                                    nav.showSheet(.editTask(id), for: viewID)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .defaultBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Task inbox")
                        .themedSubtitle()
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .regular))
                    }
                    .themedSecondaryButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        nav.showSheet(.addTask, for: viewID)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .regular))
                    }
                }
            }
            .sheet(item: nav.sheetBinding(for: viewID)) { route in
                ViewRouter.sheetView(for: route, navigationManager: nav, builders: ViewBuilders(
                    buildAddTaskView: {
                        AnyView(AddEditTaskView(
                            viewModel: AddEditTaskViewModel(mode: .add, repository: viewModel.repository)
                        ))
                    },
                    buildEditTaskView: { id in
                        guard let task = editableUserTask, task.id == id else {
                            return AnyView(FallbackView(message: "Could not display edit task screen", nav: nav, viewID: viewID))
                        }
                        return AnyView(AddEditTaskView(
                            viewModel: AddEditTaskViewModel(mode: .edit(task), repository: viewModel.repository)
                        ))
                    }
                ))
            }
            .task {
                await viewModel.fetchTasks()
                await viewModel.fetchTags()
            }
        }
    }
}
