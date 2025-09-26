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
        
        ZStack {
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
                .sheet(item: nav.sheetBinding(for: viewID)) { route in
                    ViewRouter.sheetView(for: route, navigationManager: nav, factory: factory)
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
                    .sheet(item: nav.sheetBinding(for: viewID)) { route in
                        ViewRouter.sheetView(for: route, navigationManager: nav, factory: factory)
                    }
                }
            }
            
            ToolbarView(blurStyle: .systemUltraThinMaterial) {
                Button(action: {
                    onDismiss?()
                    dismiss()
                    nav.pop()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .regular))
                }
            } center: {
                Text("Task inbox")
                    .themedHeadline()
            } trailing: {
                HStack(alignment: .center, spacing: 16) {
                    Button(action: {
                        nav.showSheet(.addTask, for: viewID)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .regular))
                    }
                    .background(
                        Color.clear
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    )
                }
            }
        }
        .defaultBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle("")
        .task {
            await viewModel.fetchTasks()
        }
    }
}
