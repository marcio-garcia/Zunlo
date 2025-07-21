//
//  TaskInboxView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI

struct TaskInboxView: View {
    @StateObject private var viewModel: UserTaskInboxViewModel
    @State private var editableUserTask: UserTask?
    
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
                        viewModel.showAddSheet = true
                    }

                case .error(let message):
                    Text("Error: \(message)")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()

                case .loaded:
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            
                            ForEach(viewModel.incompleteTasks) { task in
                                TaskRow(task: task) {
                                    viewModel.toggleCompletion(for: task)
                                } onTap: {
                                    editableUserTask = task
                                }
                            }
                            
                            Divider()
                            
                            ForEach(viewModel.completeTasks) { task in
                                TaskRow(task: task) {
                                    viewModel.toggleCompletion(for: task)
                                } onTap: {
                                    editableUserTask = task
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .defaultBackground()
            .navigationTitle("Task Inbox")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showAddSheet = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                AddEditTaskView(
                    viewModel: AddEditTaskViewModel(mode: .add, repository: viewModel.repository)
                )
            }
            .sheet(item: $editableUserTask, content: { task in
                AddEditTaskView(
                    viewModel: AddEditTaskViewModel(mode: .edit(task), repository: viewModel.repository)
                )
            })
            .task {
                await viewModel.fetchTasks()
            }
        }
    }
}
