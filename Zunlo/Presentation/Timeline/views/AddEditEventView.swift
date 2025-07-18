//
//  AddEditEventView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import SwiftUI

struct AddEditEventView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: AddEditEventViewModel
    @State private var showUntil: Bool = false
    @State private var error: String?

    private let recurrenceOptions: [String] = ["daily", "weekly", "monthly"]

    var body: some View {
        NavigationStack {
            Form {
                eventDetailsSection
                dateTimeSection
                colorSection

                if viewModel.showsRecurrenceSection {
                    recurrenceSection
                }

                ReminderEditorView(triggers: $viewModel.reminderTriggers.replacingNil(with: []))

                if viewModel.showsCancelSection && viewModel.isEditingSingleOrOverride {
                    cancelSection
                } else if viewModel.isEditingAll {
                    deleteSection
                }
            }
            .navigationBarTitleDisplayMode(.inline) // or .large
            .confirmationDialog(
                "Delete Event",
                isPresented: $viewModel.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete this event") {
                    viewModel.showDeleteConfirmation = false
                    viewModel.delete { result in
                        switch result {
                        case .success:
                            dismiss()
                        case .failure(let err):
                            error = err.localizedDescription
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.showDeleteConfirmation = false
                }
            }
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
                    .disabled(viewModel.title.isEmpty || viewModel.isProcessing)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error Saving Event", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK", role: .cancel) { error = nil }
            } message: {
                Text(error ?? "Unknown error.")
            }
        }
    }

    private var eventDetailsSection: some View {
        Section {
            Group {
                TextField("Title", text: $viewModel.title)
                TextField("Location", text: $viewModel.location)
                TextField("Notes", text: $viewModel.notes, axis: .vertical)
            }
            .themedBody()
        } header: {
            Text("Event Details")
                .themedCaption()
        }
    }

    private var dateTimeSection: some View {
        Section {
            DatePicker(selection: $viewModel.startDate, displayedComponents: [.date, .hourAndMinute]) {
                Text("Start")
                    .themedBody()
            }
            DatePicker(selection: $viewModel.endDate, displayedComponents: [.date, .hourAndMinute]) {
                Text("End")
                    .themedBody()
            }
        } header: {
            Text("Date & Time")
                .themedCaption()
        }
    }

    private var colorSection: some View {
        Section {
            ColorPickerView(selectedColor: $viewModel.color)
        }
    }

    private var recurrenceSection: some View {
        Section {
            Toggle(isOn: $viewModel.isRecurring) { Text("Recurring") .themedBody() }

            if viewModel.isRecurring {
                Picker("Repeat", selection: $viewModel.recurrenceType) {
                    ForEach(recurrenceOptions, id: \.self) { option in
                        Text(option.capitalized).tag(option)
                    }
                }
                .themedBody()

                Stepper("Interval: \(viewModel.recurrenceInterval)",
                        value: $viewModel.recurrenceInterval,
                        in: 1...30
                )
                .themedBody()

                if viewModel.recurrenceType == "weekly" {
                    WeekdayPicker(selection: $viewModel.byWeekday)
                        .themedCaption()
                }

                if viewModel.recurrenceType == "monthly" {
                    MonthdayPicker(selection: $viewModel.byMonthday)
                        .themedCaption()
                }

                Toggle(isOn: $showUntil) { Text("Set End Date") .themedBody() }

                if showUntil {
                    DatePicker("Until", selection: Binding(
                        get: { viewModel.until ?? Date() },
                        set: { viewModel.until = $0 }
                    ), displayedComponents: [.date])
                    .themedBody()
                }
            }
        } header: {
            Text("Recurrence")
                .themedCaption()
        }
        .onChange(of: showUntil) { oldValue, newValue in
            if !newValue {
                viewModel.until = nil
            } else if viewModel.until == nil {
                viewModel.until = Date()
            }
        }
    }

    private var cancelSection: some View {
        Section {
            Toggle("Cancelled", isOn: $viewModel.isCancelled)
                .themedBody()
                .tint(.red)
        }
    }

    private var deleteSection: some View {
        Section {
            HStack {
                Spacer()
                Button {
                    viewModel.showDeleteConfirmation = true
                } label: {
                    Text("Delete")
                }
                .themedSecondaryButton()
                Spacer()
            }
        }
    }
}
