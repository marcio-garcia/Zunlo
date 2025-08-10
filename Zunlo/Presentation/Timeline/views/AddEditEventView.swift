//
//  AddEditEventView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import SwiftUI

struct AddEditEventView: View {
    @State var viewID = UUID()
    
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: AddEditEventViewModel
    @EnvironmentObject var nav: AppNav
    @State private var showUntil: Bool = false
    @State private var error: String?
    
    var onDismiss: ((Date?) -> Void)?
    
    private let recurrenceOptions: [String] = ["daily", "weekly", "monthly"]
    
    var body: some View {
        let eventFactory = EventViewFactory(viewID: viewID, nav: nav)
        let factory = NavigationViewFactory(event: eventFactory)
        
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    eventDetailsSection
                    dateTimeSection
                    colorSection
                    
                    if viewModel.showsRecurrenceSection {
                        recurrenceSection
                    }
                    
                    reminderSection
                    
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
                isPresented: nav.isDialogPresented(for: viewID), // $viewModel.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                if let route = nav.dialogRoute(for: viewID) {
                    ViewRouter.dialogView(
                        for: route,
                        navigationManager: nav,
                        factory: factory) { option in
                            switch option {
                            case "delete":
                                Task {
                                    await viewModel.delete()
                                    await MainActor.run {
                                        nav.dismissDialog(for: viewID)
                                        dismiss()
                                        onDismiss?(nil)
                                    }
                                }
                            case "cancel":
                                nav.dismissDialog(for: viewID)
                            default: break
                            }
                        }
                    //                Button("Delete this event") {
                    //                    viewModel.showDeleteConfirmation = false
                    //                    viewModel.delete { result in
                    //                        switch result {
                    //                        case .success:
                    //                            dismiss()
                    //                        case .failure(let err):
                    //                            error = err.localizedDescription
                    //                        }
                    //                    }
                    //                }
                    //                Button("Cancel", role: .cancel) {
                    //                    viewModel.showDeleteConfirmation = false
                    //                }
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
                            case .success(let startDate):
                                dismiss()
                                onDismiss?(startDate)
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
                Button("Ok", role: .cancel) { error = nil }
            } message: {
                Text(error ?? "Unknown error.")
            }
        }
    }

    // MARK: Event details section
    
    private var eventDetailsSection: some View {
        RoundedSection(title: String(localized: "Event Details")) {
            Group {
                TextField("Title", text: $viewModel.title)
                TextField("Location", text: $viewModel.location)
                TextField("Notes", text: $viewModel.notes, axis: .vertical)
            }
            .themedBody()
        }
    }

    // MARK: Date and time section
    
    private var dateTimeSection: some View {
        RoundedSection(title: String(localized: "Date & Time")) {
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

    // MARK: Color picker section
    
    private var colorSection: some View {
        RoundedSection {
            ColorPickerView(selectedColor: $viewModel.color)
        }
    }

    // MARK: Recurrence section
    
    private var recurrenceSection: some View {
        RoundedSection(title: String(localized: "Recurrence")) {
            Toggle(isOn: $viewModel.isRecurring) { Text("Recurring") .themedBody() }

            if viewModel.isRecurring {
                HStack {
                    Text("Repeat")
                        .themedBody()
                    Spacer()
                    Picker("", selection: $viewModel.recurrenceType) {
                        ForEach(recurrenceOptions, id: \.self) { option in
                            Text(localizedString(option)).tag(option)
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

    // MARK: Reminder section
    
    private var reminderSection: some View {
        ReminderEditorView(
            triggers: $viewModel.reminderTriggers.replacingNil(with: [])
        )
    }
    
    // MARK: Cancel section
    
    private var cancelSection: some View {
        RoundedSection {
            Toggle("Cancelled", isOn: $viewModel.isCancelled)
                .themedBody()
                .tint(.red)
        }
    }

    // MARK: Delete section
    
    private var deleteSection: some View {
        RoundedSection {
            HStack {
                Spacer()
                Button {
                    nav.showDialog(.deleteEvent(id: UUID()), for: viewID)
//                    viewModel.showDeleteConfirmation = true
                } label: {
                    Text("Delete")
                }
                .themedSecondaryButton()
                Spacer()
            }
        }
    }
    
    private func localizedString(_ text: String) -> String {
        let localized = NSLocalizedString(
            text,
            comment: "Recurring event frequency options"
        )
        return localized.capitalized
    }
}
