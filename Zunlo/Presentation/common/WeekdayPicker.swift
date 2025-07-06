//
//  WeekdayPicker.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import SwiftUI

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        HStack {
            ForEach(0..<7, id: \.self) { i in
                Button {
                    if selection.contains(i) {
                        selection.remove(i)
                    } else {
                        selection.insert(i)
                    }
                } label: {
                    Text(days[i])
                        .padding(6)
                        .background(selection.contains(i) ? Color.accentColor.opacity(0.7) : Color.gray.opacity(0.2))
                        .cornerRadius(6)
                        .foregroundColor(selection.contains(i) ? .white : .primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
