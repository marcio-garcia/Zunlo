//
//  TaskInboxView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI

struct TaskInboxView: View {
    @Environment(\.dismiss) private var dismiss
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
                        viewModel.showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .regular))
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
                await viewModel.fetchTags()
            }
        }
    }
}
