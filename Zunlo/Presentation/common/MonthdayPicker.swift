//
//  MonthdayPicker.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import SwiftUI

struct MonthdayPicker: View {
    @Binding var selection: Set<Int>
    let days = Array(1...31)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(days, id: \.self) { day in
                    Button {
                        if selection.contains(day) {
                            selection.remove(day)
                        } else {
                            selection.insert(day)
                        }
                    } label: {
                        Text("\(day)")
                            .frame(width: 32, height: 32)
                            .background(selection.contains(day) ? Color.accentColor.opacity(0.7) : Color.gray.opacity(0.2))
                            .cornerRadius(16)
                            .foregroundColor(selection.contains(day) ? .white : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}
