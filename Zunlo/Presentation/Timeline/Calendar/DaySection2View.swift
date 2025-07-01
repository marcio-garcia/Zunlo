//
//  DaySection2View.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/1/25.
//

import SwiftUI

struct DaySection2View: View {
    let date: Date
    let isToday: Bool
    let events: [Event]
    let onEdit: (Event) -> Void
    let onDelete: (Event) -> Void

    private func dateString(_ date: Date) -> String {
        date.formattedDate(dateFormat: "E, MMM d")
    }

    var body: some View {
        Section(header:
            HStack {
                Text(dateString(date))
                    .font(.headline)
                    .foregroundColor(isToday ? .accentColor : .primary)
                if isToday {
                    Text("Today")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .padding(.leading, 4)
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .background(Color(.systemBackground))
        ) {
            if events.isEmpty {
                Text("No events")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(events) { event in
                    EventRowView(
                        event: event,
                        onEdit: { onEdit(event) },
                        onDelete: { onDelete(event) }
                    )
                }
            }
        }
    }
}

