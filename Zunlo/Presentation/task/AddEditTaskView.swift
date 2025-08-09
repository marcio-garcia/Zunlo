//
//  AddEditTaskView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI
import FlowNavigator

struct AddEditTaskView: View {
    @State var viewID = UUID()
    
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    @State private var tagEditorHeight: CGFloat = .zero
    @StateObject var viewModel: AddEditTaskViewModel
    
    var nav: AppNav
    
    var body: some View {
        
        let taskFactory = TaskViewFactory(
            viewID: viewID,
            nav: nav,
            repository: viewModel.repository,
            addEditTaskViewModel: viewModel
        )
        let factory = NavigationViewFactory(task: taskFactory)
        
        formContent
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(viewModel.navigationTitle())
                        .themedSubtitle()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save { result in
                            switch result {
                            case .success:
                                dismiss()
                            case .failure(let err):
                                error = err.localizedDescription
                            }
                        }
                    }
                    .themedSecondaryButton(isEnabled: isEnabled)
                    .disabled(!isEnabled)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .themedSecondaryButton()
                }
            }
            .confirmationDialog(
                "Delete task",
                isPresented: nav.isDialogPresented(for: viewID),
                titleVisibility: .visible
            ) {
                if let route = nav.dialogRoute(for: viewID) {
                    ViewRouter.dialogView(for: route, navigationManager: nav, factory: factory)
                }
            }
            .alert("Error Saving Task", isPresented: isShowingError) {
                Button("Ok", role: .cancel) { error = nil }
            } message: {
                Text(error ?? "Unknown error.")
            }
            .themedBody()
        
    }
    
    // MARK: - View Sections
    
    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                taskDetailsSection
                taskTimingSection
                taskTagsSection
                // commented out reminders for tasks
                //                ReminderEditorView(triggers: $viewModel.reminderTriggers)
                if case AddEditTaskViewModel.Mode.edit = viewModel.mode {
                    deleteSection
                }
            }
            .padding()
        }
        .defaultBackground()
    }
    
    private var taskDetailsSection: some View {
        RoundedSection(title: String(localized: "Task Details")) {
            TextField("Title", text: $viewModel.title)
            
            TextField("Notes", text: $viewModel.notes, axis: .vertical)
            
            HStack {
                Text("Priority")
                    .themedBody()
                Spacer()
                Picker("", selection: $viewModel.priority) {
                    ForEach(UserTaskPriority.allCases, id: \.self) { priority in
                        Text(priority.description.capitalized).tag(priority)
                            .themedBody()
                    }
                }
                .pickerStyle(.menu) // or .segmented, .wheel, etc.
            }
            
            Toggle("Completed", isOn: $viewModel.isCompleted)
        }
    }
    
    private var taskTimingSection: some View {
        RoundedSection {
            Toggle(isOn: $viewModel.hasDueDate) { Text("Set due date").themedBody() }
            
            if viewModel.hasDueDate {
                DatePicker("Due Date",
                           selection: $viewModel.dueDate.replacingNil(with: Date()),
                           displayedComponents: [.date])
                .themedBody()
                .environment(\.locale, .autoupdatingCurrent)
            }
        }
    }
    
    private var taskTagsSection: some View {
        RoundedSection(title: "Tags") {
            TagChipListView(
                tags: $viewModel.tags,
                mode: .editable,
                allPossibleTags: viewModel.allUniqueTags
            )
        }
    }
    
    private var deleteSection: some View {
        RoundedSection {
            HStack {
                Spacer()
                Button {
                    viewModel.onDelete = {
                        Task {
                            await MainActor.run {
                                self.dismiss()
                            }
                        }
                    }
                    nav.showDialog(.deleteTask, for: viewID)
                } label: {
                    Text("Delete")
                }
                .themedSecondaryButton()
                Spacer()
            }
        }
    }
    
    private var isShowingError: Binding<Bool> {
        Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )
    }
    
    private var isEnabled: Bool {
        return !(viewModel.title.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isProcessing)
    }
}
