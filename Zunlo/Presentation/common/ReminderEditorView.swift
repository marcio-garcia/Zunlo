//
//  ReminderEditorView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/17/25.
//

import SwiftUI
import GlowUI

struct ReminderEditorView: View {
    @Binding var triggers: [ReminderTrigger]

    var body: some View {
        RoundedSection(title: String(localized: "Reminders")) {
            Text("Set event reminders by choosing how long before the start time you want to be notified.")
                .appFont(.caption)
                .foregroundStyle(Color.theme.tertiaryText)
            
            ForEach(triggers.indices, id: \.self) { index in
                VStack {
//                    TextField("Note for the reminder", text: Binding(
//                        get: { triggers[index].message ?? "" },
//                        set: { triggers[index].message = $0 }
//                    ))
//                    .themedCaption()
                    
                    VStack(alignment: .leading) {
                        Slider(
                            value: Binding(
                                get: { triggers[index].timeBeforeDue / 60 },
                                set: { triggers[index].timeBeforeDue = $0 * 60 }
                            ),
                            in: 0...120,
                            step: 5
                        )

                        Text(formatReminderTime(Int(triggers[index].timeBeforeDue / 60)))
                            .themedCaption()
                    }
                }
            }

            Button {
                triggers.append(ReminderTrigger(timeBeforeDue: 900, message: nil))
            } label: {
                Label("Add Reminder", systemImage: "plus")
            }
            .themedSecondaryButton()

            if !triggers.isEmpty {
                Button(role: .destructive) {
                    triggers.removeAll()
                } label: {
                    Text("Clear All Reminders")
                }
                .themedSecondaryButton()
            }
        }
    }
    
    func formatReminderTime(_ minutes: Int) -> String {
        if minutes == 0 {
            return String(localized: "At time of task")
        }

        let days = minutes / 1440
        let hours = (minutes % 1440) / 60
        let remainingMinutes = minutes % 60

        var components: [String] = []

        if days > 0 {
            components.append(String(localized: "\(days) day\(days == 1 ? "" : "s")"))
        }

        if hours > 0 {
            components.append(String(localized: "\(hours)h"))
        }

        if remainingMinutes > 0 {
            components.append(String(localized: "\(remainingMinutes) min"))
        }

        return components.joined(separator: " ") + " " + String(localized: "before")
    }
}
