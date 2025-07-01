//
//  EventView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/30/25.
//

import SwiftUI

struct EventView: View {
    let event: Event
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(event.dueDate.formattedDate(dateFormat: "HH:mm"))
                .font(.headline)
                .frame(width: 60, alignment: .trailing)
            Text(event.title)
                .font(.body)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}
