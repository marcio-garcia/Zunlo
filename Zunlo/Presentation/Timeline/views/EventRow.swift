//
//  EventRow.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import SwiftUI
import GlowUI

struct EventRow: View {
    let occurrence: EventOccurrence
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                let titleColor = titleColor(occurrence: occurrence)
                Rectangle()
                    .fill(eventIndicatorColor(occurrence: occurrence))
                    .frame(width: 6)
                    .cornerRadius(3)
                VStack(alignment: .leading) {
                    Text(occurrence.title)
                        .font(AppFontStyle.subtitle.font())
                        .foregroundStyle(titleColor)
                        .strikethrough(occurrence.isCancelled, color: titleColor)
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
    
    func titleColor(occurrence: EventOccurrence) -> Color {
        if occurrence.isFakeOccForEmptyToday || occurrence.isCancelled {
            return Color.theme.tertiaryText
        } else {
            return Color.theme.text
        }
    }
    
    func timeColor(occurrence: EventOccurrence) -> Color {
        return occurrence.isCancelled ? Color.theme.tertiaryText : Color.theme.secondaryText
    }
    
    func eventIndicatorColor(occurrence: EventOccurrence) -> Color {
        if occurrence.isFakeOccForEmptyToday || occurrence.isCancelled {
            return Color.theme.disabled
        } else {
            return Color(hex: occurrence.color.rawValue)!
        }
    }
}
