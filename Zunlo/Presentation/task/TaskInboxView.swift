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
    @EnvironmentObject var nav: AppNav
    @StateObject private var viewModel: UserTaskInboxViewModel
    @State private var editableUserTask: UserTask?
    @State private var tagEditorHeight: CGFloat = .zero
    
    init(repository: UserTaskRepository) {
        _viewModel = StateObject(wrappedValue: UserTaskInboxViewModel(repository: repository))
    }
    
    var body: some View {
        let taskViewFactory = TaskViewFactory(
            viewID: viewID,
            nav: nav,
            repository: viewModel.repository,
            editableTaskProvider: { self.editableUserTask }
        )
        let factory = NavigationViewFactory(task: taskViewFactory)
        
        Group {
            switch viewModel.state {
            case .loading:
                VStack {
                    ProgressView("Loading...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .defaultBackground()
                
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
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Task inbox")
                    .themedSubtitle()
            }
            ToolbarItem(placement: .cancellationAction) {
                Button(action: {
                    dismiss()
                    nav.pop()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .regular))
                }
                .themedSecondaryButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    nav.showSheet(.addTask, for: viewID)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .regular))
                }
            }
        }
        .sheet(item: nav.sheetBinding(for: viewID)) { route in
            ViewRouter.sheetView(for: route, navigationManager: nav, factory: factory)
        }
        .task {
            await viewModel.fetchTasks()
            await viewModel.fetchTags()
        }
    }
}
