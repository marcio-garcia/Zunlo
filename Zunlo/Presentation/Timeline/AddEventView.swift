//
//  AddEventView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import SwiftUI

struct AddEventView: View {
    @EnvironmentObject var repository: EventRepository
    @Environment(\.dismiss) private var dismiss
    @State private var eventTitle: String = ""
    @State private var eventDate: Date = Date()
    @State private var isSaving = false

    let eventToEdit: Event? // Pass nil to add, or event to edit
    
    init(eventToEdit: Event? = nil) {
        _eventTitle = State(initialValue: eventToEdit?.title ?? "")
        _eventDate = State(initialValue: eventToEdit?.dueDate ?? Date())
        self.eventToEdit = eventToEdit
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Title", text: $eventTitle)
                    DatePicker("Due Date", selection: $eventDate)
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

    private func saveEvent() {
        guard !eventTitle.isEmpty else { return }
        isSaving = true
        Task {
            do {
                let event: Event
                if let editing = eventToEdit {
                    event = Event(
                        id: editing.id,
                        userId: editing.userId,
                        title: eventTitle,
                        createdAt: editing.createdAt,
                        dueDate: eventDate,
                        isComplete: editing.isComplete
                    )
                    try await repository.update(event)
                } else {
                    event = Event(
                        id: nil,
                        userId: nil,
                        title: eventTitle,
                        dueDate: eventDate,
                        isComplete: false
                    )
                    try await repository.save(event)
                }
            } catch {
                // Add error handling UI
                print("Failed to save event: \(error)")
            }
            dismiss()
            isSaving = false
        }
    }
}
