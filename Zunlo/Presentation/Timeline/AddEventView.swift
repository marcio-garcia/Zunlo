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

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Title", text: $eventTitle)
                    DatePicker("Due Date", selection: $eventDate)
                }
            }
            .navigationTitle("Add Event")
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
            let newEvent = Event(id: nil, userId: nil, title: eventTitle, dueDate: eventDate, isComplete: false)
            do {
                try await repository.addEvent(newEvent)
                dismiss()
            } catch {
                // Add error handling UI
                print("Failed to add event: \(error)")
            }
            isSaving = false
        }
    }
}
