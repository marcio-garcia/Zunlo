//
//  AddEditTaskView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI

struct AddEditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    @StateObject var viewModel: AddEditTaskViewModel

    var body: some View {
        NavigationStack {
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
                .alert("Error Saving Task", isPresented: isShowingError) {
                    Button("OK", role: .cancel) { error = nil }
                } message: {
                    Text(error ?? "Unknown error.")
                }
                .themedBody()
        }
    }

    // MARK: - View Sections

    private var formContent: some View {
        Form {
            taskDetailsSection
            taskTimingSection
            taskTagsSection
            ReminderEditorView(triggers: $viewModel.reminderTriggers)
        }
    }

    private var taskDetailsSection: some View {
        Section {
            TextField("Title", text: $viewModel.title)

            TextField("Notes", text: $viewModel.notes, axis: .vertical)

            Picker("Priority", selection: $viewModel.priority) {
                ForEach(UserTaskPriority.allCases, id: \.self) { priority in
                    Text(priority.description.capitalized).tag(priority)
                }
            }
            
            Toggle("Completed", isOn: $viewModel.isCompleted)
        } header: {
            Text("Task Details")
        }
    }

    private var taskTimingSection: some View {
        Section {
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
        Section {
            TagEditorView(tags: $viewModel.tags)
                .frame(height: 200)
        } header: {
            Text("Tags")
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )
    }
    
    private var isEnabled: Bool {
        return !(viewModel.title.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSaving)
    }
}
