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
                Text(event.dueDate.formattedDate(dateFormat: "HH:mm"))
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .frame(width: 50, alignment: .trailing)
                Text(event.title)
                    .font(.body)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(Color.blue.opacity(0.8))
        .foregroundStyle(.background)
        .cornerRadius(4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: ButtonRole.destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

