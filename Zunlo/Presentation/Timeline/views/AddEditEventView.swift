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
    
    var onDismiss: (() -> Void)?
    
    private let recurrenceOptions: [String] = [
        RecurrenceFrequesncy.daily.rawValue,
        RecurrenceFrequesncy.weekly.rawValue,
        RecurrenceFrequesncy.monthly.rawValue,
        RecurrenceFrequesncy.yearly.rawValue
    ]
    
    var body: some View {
        let eventFactory = EventViewFactory(viewID: viewID, nav: nav, userId: viewModel.userId)
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
                "Delete event",
                isPresented: nav.isDialogPresented(for: viewID),
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
                                    if await viewModel.delete() {
                                        nav.dismissDialog(for: viewID)
                                        onDismiss?()
                                        dismiss()
                                    }
                                }
                            case "cancel":
                                nav.dismissDialog(for: viewID)
                            default: break
                            }
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(viewModel.navigationTitle())
                        .themedSubtitle()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                onDismiss?()
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.title.isEmpty || viewModel.isProcessing)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .errorAlert(viewModel.errorHandler)
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
            
            VStack {
                DatePicker(selection: $viewModel.endDate, in: viewModel.startDate..., displayedComponents: [.date, .hourAndMinute]) {
                    Text("End")
                        .themedBody()
                }
                if viewModel.isRecurring {
                    Text("End date & time for each event occurrence. Doesn’t change the repeat schedule")
                        .themedFootnote()
                }
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
                    .pickerStyle(.menu)
                }

                Stepper("Interval: \(viewModel.recurrenceInterval)",
                        value: $viewModel.recurrenceInterval,
                        in: 1...30
                )
                .themedBody()

                if viewModel.recurrenceType == RecurrenceFrequesncy.weekly.rawValue {
                    WeekdayPicker(selection: $viewModel.byWeekday)
                        .themedCaption()
                }

                if viewModel.recurrenceType == RecurrenceFrequesncy.monthly.rawValue {
                    MonthdayPicker(selection: $viewModel.byMonthday)
                        .themedCaption()
                }

                Toggle(isOn: $showUntil) { Text("Set End Date") .themedBody() }

                if showUntil {
                    DatePicker("Repeat until", selection: Binding(
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
                    nav.showDialog(.deleteEvent(mode: viewModel.mode), for: viewID)
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
