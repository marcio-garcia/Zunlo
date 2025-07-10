//
//  ColorPickerView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/9/25.
//

import SwiftUI

struct ColorPickerView: View {
    @Binding var selectedColor: String
    var colors = EventColor.allCases.map { $0.rawValue }

    var body: some View {
        HStack {
            ForEach(colors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex) ?? .clear)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().stroke(selectedColor == hex ? Color.black : .clear, lineWidth: 2)
                    )
                    .onTapGesture { selectedColor = hex }
            }
        }
    }
}
