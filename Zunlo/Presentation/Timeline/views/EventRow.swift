//
//  EventRow.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import SwiftUI

struct EventRow: View {
    let occurrence: EventOccurrence
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(occurrence.title)
                Text(formatDate(start: occurrence.startDate, end: occurrence.endDate))
            }
            Spacer()
            if occurrence.isOverride {
                Image(systemName: "pencil")
            }
            Button(action: onEdit) {
                Image(systemName: "square.and.pencil")
            }
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
        }
    }
    
    func formatDate(start: Date, end: Date?) -> String {
        var text = occurrence.startDate.formattedDate(dateFormat: "HH:mm")
        if let endDate = end {
            text.append(" - \(endDate.formattedDate(dateFormat: "HH:mm"))")
        }
        return text
    }
}
