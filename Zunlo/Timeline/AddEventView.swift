//
//  AddEventView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import SwiftUI

struct NewEventDraft {
    var title: String = ""
    var dueDate: Date = Date()
    var reminder: Int = 5
    // add other fields
}

struct AddEventView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var newEvent: NewEventDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("+ Add Event")
                .font(.title)
            Text("Title:")
            TextField("Event name", text: $newEvent.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Text("Time:")
            DatePicker("Time", selection: $newEvent.dueDate, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
            
            Text("Remind me")
            Picker("Reminder", selection: $newEvent.reminder) {
                Text("None").tag(0)
                Text("5 min before").tag(5)
                Text("10 min before").tag(10)
                Text("30 min before").tag(30)
            }
            .pickerStyle(MenuPickerStyle())

            HStack {
                Button("Save") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top)
            Spacer()
        }
        .padding()
    }
}
