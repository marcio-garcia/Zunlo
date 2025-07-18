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
    @FocusState private var focusTitle: Bool
    @State private var showUntil: Bool = false
    @State private var error: String?
    
    private let recurrenceOptions: [String]  = ["daily", "weekly", "monthly"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $viewModel.title)
                    TextField("Location", text: $viewModel.location)
                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                } header: {
                    Text("Event Details")
                }
                
                Section {
                    DatePicker("Start", selection: $viewModel.startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End", selection: $viewModel.endDate, displayedComponents: [.date, .hourAndMinute])
                } header: {
                    Text("Date & Time")
                }
                
                Section {
                    ColorPickerView(selectedColor: $viewModel.color)
                }

                // Recurrence only for add/editAll
                if viewModel.showsRecurrenceSection {
                    Section {
                        Toggle("Recurring", isOn: $viewModel.isRecurring)
                        if viewModel.isRecurring {
                            Picker("Repeat", selection: $viewModel.recurrenceType) {
                                ForEach(recurrenceOptions, id: \.self) { option in
                                    Text(option.capitalized).tag(option)
                                }
                            }
                            Stepper("Interval: \(viewModel.recurrenceInterval)", value: $viewModel.recurrenceInterval, in: 1...30)
                            if viewModel.recurrenceType == "weekly" {
                                WeekdayPicker(selection: $viewModel.byWeekday)
                            }
                            if viewModel.recurrenceType == "monthly" {
                                MonthdayPicker(selection: $viewModel.byMonthday)
                            }
                            Toggle("Set End Date", isOn: $showUntil)
                            if showUntil {
                                DatePicker("Until", selection: Binding(
                                    get: { viewModel.until ?? Date() },
                                    set: { viewModel.until = $0 }
                                ), displayedComponents: [.date])
                            }
                        }
                    } header: {
                        Text("Recurrence")
                    }
                    .onChange(of: showUntil, { oldValue, newValue in
                        if !newValue { viewModel.until = nil }
                        else if viewModel.until == nil { viewModel.until = Date() }
                    })
                }
                
                ReminderEditorView(triggers: $viewModel.reminderTriggers.replacingNil(with: []))

                // Cancel single occurrence for override
                if viewModel.showsCancelSection && viewModel.isEditingSingleOrOverride {
                    Section {
                        Toggle("Cancelled", isOn: $viewModel.isCancelled)
                            .tint(.red)
                    }
                }
            }
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
                    .disabled(viewModel.title.isEmpty || viewModel.isSaving)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focusTitle = true }
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
}
