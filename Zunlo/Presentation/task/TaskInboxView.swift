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
    
    var onDismiss: (() -> Void)?
    
    init(repository: UserTaskRepository, onDismiss: (() -> Void)?) {
        _viewModel = StateObject(wrappedValue: UserTaskInboxViewModel(taskRepo:repository))
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        let taskViewFactory = TaskViewFactory(
            viewID: viewID,
            nav: nav,
            userId: UUID(),
            onAddEditTaskViewDismiss: {
                Task { await viewModel.fetchTasks() }
            }
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
                VStack {
                    TagChipListView(
                        tags: $viewModel.tags,
                        mode: .readonly(selectable: true),
                        onTagsChanged: { _ in await viewModel.filter() }
                    )
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.incompleteTasks) { task in
                                TaskRow(task: task, chipType: .small) {
                                    viewModel.toggleCompletion(for: task)
                                } onTap: {
                                    editableUserTask = task
                                    nav.showSheet(.editTask(task), for: viewID)
                                }
                            }
                            
                            Divider()
                            
                            ForEach(viewModel.completeTasks) { task in
                                TaskRow(task: task, chipType: .small) {
                                    viewModel.toggleCompletion(for: task)
                                } onTap: {
                                    editableUserTask = task
                                    nav.showSheet(.editTask(task), for: viewID)
                                }
                            }
                        }
                        .padding()
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden()
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Task inbox")
                                .themedSubtitle()
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button(action: {
                                onDismiss?()
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
                }
                .defaultBackground()
            }
        }
        .task {
            await viewModel.fetchTasks()
        }
    }
}
