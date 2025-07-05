//
//  AddEventView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import SwiftUI

enum RecurrenceType: String, CaseIterable, Identifiable {
    case none = "Does not repeat"
    case daily = "Daily"
    case weekly = "Every week"
    case monthly = "Every month"
    var id: String { rawValue }
}

struct AddEventView: View {
    @EnvironmentObject var repository: EventRepository
    @Environment(\.dismiss) private var dismiss

    @State private var eventTitle: String = ""
    @State private var eventDate: Date = Date()
    @State private var recurrenceType: RecurrenceType = .none
    @State private var isSaving = false

    let eventToEdit: Event?
    let parentEventForException: Event?
    let overrideDate: Date?
    let occurrenceDate: Date?

    init(eventToEdit: Event? = nil, parentEventForException: Event? = nil, overrideDate: Date? = nil, occurrenceDate: Date? = nil) {
        _eventTitle = State(initialValue: eventToEdit?.title ?? "")
        
        if let recurrence = eventToEdit?.recurrence,
           recurrence != .none,
           parentEventForException == nil,
           let occDate = occurrenceDate {
            // Use the time from eventToEdit's dueDate for consistency
            let initial = occDate.settingTimeFrom(eventToEdit?.dueDate ?? occDate)
            _eventDate = State(initialValue: initial)
        } else {
            // For non-recurring events, or when editing just one instance, use dueDate
            _eventDate = State(initialValue: eventToEdit?.dueDate ?? Date())
        }
        
        if let recurrence = eventToEdit?.recurrence {
            switch recurrence {
            case .none: _recurrenceType = State(initialValue: .none)
            case .daily: _recurrenceType = State(initialValue: .daily)
            case .weekly: _recurrenceType = State(initialValue: .weekly)
            case .monthly: _recurrenceType = State(initialValue: .monthly)
            }
        }
        self.eventToEdit = eventToEdit
        self.parentEventForException = parentEventForException
        self.overrideDate = overrideDate
        self.occurrenceDate = occurrenceDate
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Title", text: $eventTitle)
                    DatePicker("Due Date", selection: $eventDate)
                    if let event = eventToEdit, event.recurrence != .none, parentEventForException == nil, let occDate = occurrenceDate {
                        Text("Editing all events. You tapped: \(occDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section(header: Text("Recurrence")) {
                    Picker("Repeat", selection: $recurrenceType) {
                        ForEach(RecurrenceType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle(eventToEdit == nil ? "Add Event" : "Edit Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEvent()
                    }
                    .disabled(eventTitle.isEmpty || isSaving)
                }
            }
        }
    }

    // Derive RecurrenceRule from type and date
    var chosenRecurrence: RecurrenceRule {
        switch recurrenceType {
        case .none: return .none
        case .daily: return .daily
        case .weekly:
            let weekday = Calendar.current.component(.weekday, from: eventDate)
            return .weekly(dayOfWeek: weekday)
        case .monthly:
            let day = Calendar.current.component(.day, from: eventDate)
            return .monthly(day: day)
        }
    }
    
    private func saveEvent() {
        guard !eventTitle.isEmpty else { return }
        isSaving = true
        Task {
            do {
                try await repository.saveEvent(
                    eventToEdit: eventToEdit,
                    parentEventForException: parentEventForException,
                    overrideDate: overrideDate,
                    newTitle: eventTitle,
                    newDate: eventDate,
                    recurrence: chosenRecurrence,
                    isComplete: eventToEdit?.isComplete ?? false
                )
            } catch {
                print("Failed to save event: \(error)")
            }
            dismiss()
            isSaving = false
        }
    }

}
