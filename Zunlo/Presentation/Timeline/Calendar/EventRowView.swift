//
//  EventRowView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/1/25.
//

import SwiftUI

struct EventRowView: View {
    let event: Event
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                Text(event.dueDate.formattedDate(dateFormat: "HH:mm"))
                    .font(.subheadline)
                    .frame(width: 50, alignment: .trailing)
                Text(event.title)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: ButtonRole.destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

