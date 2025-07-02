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

    private func day(_ date: Date) -> String {
        date.formattedDate(dateFormat: "d")
    }
    
    private func weekday(_ date: Date) -> String {
        date.formattedDate(dateFormat: "E")
    }
    
    var body: some View {
        ForEach(Array(events.enumerated()), id: \.1.id) { index, event in
            HStack(alignment: .bottom) {
                // Sidebar only for the first event of the day
                if index == 0 {
                    VStack {
                        Text(weekday(date))
                            .font(.subheadline)
                            .foregroundColor(isToday ? .accentColor : .primary)
                        Text(day(date))
                            .font(.headline)
                            .foregroundColor(isToday ? .accentColor : .primary)
                    }
                    .padding(.top)
                    .frame(width: 44)
                } else {
                    VStack {
                        Color.clear
                    }
                    .padding(.all, 0)
                    .frame(width: 44)
                }
                EventRowView(
                    event: event,
                    onEdit: { onEdit(event) },
                    onDelete: { onDelete(event) }
                )
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 16)
        }
    }
}

