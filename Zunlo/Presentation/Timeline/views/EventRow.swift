//
//  EventRow.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import SwiftUI

struct EventRow: View {
    let occurrence: EventOccurrence
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                let eventColorHex = occurrence.isFakeOccForEmptyToday ? "#E0E0E0" : occurrence.color.rawValue
                Rectangle()
                    .fill(Color(hex: eventColorHex) ?? Color.gray)
                    .frame(width: 6)
                    .cornerRadius(3)
                VStack(alignment: .leading) {
                    Text(occurrence.title)
                        .themedCallout()
                    if !occurrence.isFakeOccForEmptyToday {
                        Text(formatDate(start: occurrence.startDate, end: occurrence.endDate))
                            .themedFootnote()
                    }
                }
                Spacer()
                if occurrence.isOverride {
                    Image(systemName: "pencil")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
    
    func formatDate(start: Date, end: Date?) -> String {
        var text = occurrence.startDate.formattedDate(dateFormat: .time)
        if let endDate = end {
            text.append(" - \(endDate.formattedDate(dateFormat: .time))")
        }
        return text
    }
}
