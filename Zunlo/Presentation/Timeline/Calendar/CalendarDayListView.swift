//
//  CalendarDayListView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/3/25.
//

import SwiftUI

struct CalendarDayListView: View {
    let days: [Date]
    let repository: EventRepository
    let onEdit: (Event, Date) -> Void
    let onDelete: (Event) -> Void

    var body: some View {
        List {
            ForEach(days, id: \.self) { date in
                DaySection2View(
                    date: date,
                    isToday: Calendar.current.isDateInToday(date),
                    events: repository.events(on: date),
                    onEdit: { onEdit($0, date) },
                    onDelete: { onDelete($0) }
                )
                .id(date.formattedDate(dateFormat: "yyyy-MM-dd"))
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}
