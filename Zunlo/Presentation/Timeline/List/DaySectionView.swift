//
//  DaySectionView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/30/25.
//

import SwiftUI

struct DaySectionView: View {
    let date: Date
    let isToday: Bool
    let events: [Event]
    let expanded: Bool
    let onHeaderTap: () -> Void
    let onEdit: (Event) -> Void
    let onDelete: (Event) -> Void

    var body: some View {
        Section(
            header:
                HStack {
                    Text(date.formattedDate(dateFormat: "E, MMM d"))
                        .font(.headline)
                    if isToday {
                        Text("TODAY")
                            .foregroundColor(.accentColor)
                            .font(.subheadline)
                            .padding(.leading, 4)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onHeaderTap()
                }
        ) {
            if expanded {
                if events.isEmpty {
                    Text("No events")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(events) { event in
                        EventView(
                            event: event,
                            onEdit: { onEdit(event) },
                            onDelete: { onDelete(event) }
                        )
                    }
                }
            }
        }
    }
}

