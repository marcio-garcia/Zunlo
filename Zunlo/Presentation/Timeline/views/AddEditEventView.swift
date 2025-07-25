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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                .padding()
            }
            .defaultBackground()
            .navigationBarTitleDisplayMode(.inline)
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
        RoundedSection(title: "Event Details") {
            Group {
                TextField("Title", text: $viewModel.title)
                TextField("Location", text: $viewModel.location)
                TextField("Notes", text: $viewModel.notes, axis: .vertical)
            }
            .themedBody()
        }
    }

    private var dateTimeSection: some View {
        RoundedSection(title: "Date & Time") {
            DatePicker(selection: $viewModel.startDate, displayedComponents: [.date, .hourAndMinute]) {
                Text("Start")
                    .themedBody()
            }
            .onChange(of: viewModel.startDate) { _, newStartDate in
                viewModel.updateEndDate()
            }
            
            DatePicker(selection: $viewModel.endDate, in: viewModel.startDate..., displayedComponents: [.date, .hourAndMinute]) {
                Text("End")
                    .themedBody()
            }
        }
        .onAppear() {
            UIDatePicker.appearance().minuteInterval = 5
        }
    }

    private var colorSection: some View {
        RoundedSection {
            ColorPickerView(selectedColor: $viewModel.color)
        }
    }

    private var recurrenceSection: some View {
        RoundedSection(title: "Recurrence") {
            Toggle(isOn: $viewModel.isRecurring) { Text("Recurring") .themedBody() }

            if viewModel.isRecurring {
                HStack {
                    Text("Repeat")
                        .themedBody()
                    Spacer()
                    Picker("", selection: $viewModel.recurrenceType) {
                        ForEach(recurrenceOptions, id: \.self) { option in
                            Text(option.capitalized).tag(option)
                                .themedBody()
                        }
                    }
                    .pickerStyle(.menu) // or .segmented, .wheel, etc.
                }

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
        RoundedSection {
            Toggle("Cancelled", isOn: $viewModel.isCancelled)
                .themedBody()
                .tint(.red)
        }
    }

    private var deleteSection: some View {
        RoundedSection {
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
