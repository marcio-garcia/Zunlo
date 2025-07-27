//
//  EventPlaceholderRow.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/27/25.
//

import SwiftUI

struct EventPlaceholderRow: View {
    let date: Date
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                HStack {
                    Group {
                        Text(date.formattedDate(dateFormat: .weekAndDay))
                            .foregroundStyle(Color.theme.text)
                            .font(AppFontStyle.strongBody.font())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                .frame(width: 120)
                
                Text("No events")
                    .themedCaption()
                
                Spacer()
            }
        }
    }
}
