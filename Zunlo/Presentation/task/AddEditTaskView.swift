//
//  AddEditTaskView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI

//struct AddEditTaskView: View {
//    @Environment(\.dismiss) private var dismiss
//    @FocusState private var focusTitle: Bool
//    @State private var error: String?
//    @StateObject var viewModel: AddEditTaskViewModel
//
//    var body: some View {
//        NavigationStack {
//            Form {
//                Section {
//                    TextField("Title", text: $viewModel.title)
//                        .focused($focusTitle)
//                        .submitLabel(.done)
//
//                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
//
//                    Toggle("Completed", isOn: $viewModel.isCompleted)
//                } header: {
//                    Text("Task Details")
//                }
//
//                Section {
//                    Picker("Priority", selection: $viewModel.priority) {
//                        ForEach(TaskPriority.allCases, id: \.self) { priority in
//                            Text(priority.rawValue.capitalized).tag(priority)
//                        }
//                    }
//
//                    DatePicker("Scheduled Date", selection: Binding($viewModel.scheduledDate, replacingNilWith: Date()), displayedComponents: [.date])
//                        .environment(\.locale, .autoupdatingCurrent)
//
//                    DatePicker("Due Date", selection: Binding($viewModel.dueDate, replacingNilWith: Date()), displayedComponents: [.date])
//                        .environment(\.locale, .autoupdatingCurrent)
//                } header: {
//                    Text("When")
//                }
//
//                Section {
//                    TextField("Tags (comma-separated)", text: $viewModel.tags)
//                } header: {
//                    Text("Tags")
//                }
//            }
//            .navigationTitle(viewModel.navigationTitle())
//            .toolbar {
//                ToolbarItem(placement: .confirmationAction) {
//                    Button("Save") {
//                        viewModel.save { result in
//                            switch result {
//                            case .success:
//                                dismiss()
//                            case .failure(let err):
//                                error = err.localizedDescription
//                            }
//                        }
//                    }
//                    .disabled(viewModel.title.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSaving)
//                }
//
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") { dismiss() }
//                }
//            }
//            .alert("Error Saving Task", isPresented: Binding(
//                get: { error != nil },
//                set: { if !$0 { error = nil } }
//            )) {
//                Button("OK", role: .cancel) { error = nil }
//            } message: {
//                Text(error ?? "Unknown error.")
//            }
//            .onAppear {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    focusTitle = true
//                }
//            }
//        }
//    }
//}

struct AddEditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusTitle: Bool
    @State private var error: String?
    @StateObject var viewModel: AddEditTaskViewModel

    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle(viewModel.navigationTitle())
                .toolbar {
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
                        .disabled(viewModel.title.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSaving)
                    }

                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .alert("Error Saving Task", isPresented: isShowingError) {
                    Button("OK", role: .cancel) { error = nil }
                } message: {
                    Text(error ?? "Unknown error.")
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        focusTitle = true
                    }
                }
        }
    }

    // MARK: - View Sections

    private var formContent: some View {
        Form {
            taskDetailsSection
            taskTimingSection
            taskTagsSection
        }
    }

    private var taskDetailsSection: some View {
        Section {
            TextField("Title", text: $viewModel.title)
                .focused($focusTitle)
                .submitLabel(.done)

            TextField("Notes", text: $viewModel.notes, axis: .vertical)

            Toggle("Completed", isOn: $viewModel.isCompleted)
        } header: {
            Text("Task Details")
        }
    }

    private var taskTimingSection: some View {
        Section {
            Picker("Priority", selection: $viewModel.priority) {
                ForEach(UserTaskPriority.allCases, id: \.self) { priority in
                    Text(priority.rawValue.capitalized).tag(priority)
                }
            }

            DatePicker("Scheduled Date", selection: Binding.replacingNil($viewModel.scheduledDate, with: Date()), displayedComponents: [.date])
                .environment(\.locale, .autoupdatingCurrent)

            DatePicker("Due Date", selection: Binding.replacingNil($viewModel.dueDate, with: Date()), displayedComponents: [.date])
                .environment(\.locale, .autoupdatingCurrent)
        } header: {
            Text("When")
        }
    }

    private var taskTagsSection: some View {
        Section {
            TextField("Tags (comma-separated)", text: $viewModel.tags)
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
}
