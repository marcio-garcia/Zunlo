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
                        .font(.subheadline)
                        .foregroundStyle(.black)
                    if !occurrence.isFakeOccForEmptyToday {
                        Text(formatDate(start: occurrence.startDate, end: occurrence.endDate))
                            .font(.caption)
                            .foregroundStyle(.gray)
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
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
    
    func formatDate(start: Date, end: Date?) -> String {
        var text = occurrence.startDate.formattedDate(dateFormat: "HH:mm")
        if let endDate = end {
            text.append(" - \(endDate.formattedDate(dateFormat: "HH:mm"))")
        }
        return text
    }
}
