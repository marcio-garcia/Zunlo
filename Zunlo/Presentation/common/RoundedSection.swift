//
//  RoundedSection.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/21/25.
//

import SwiftUI

struct RoundedSection<Content: View>: View {
    var title: String?
    var content: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = title {
                Text(title)
                    .themedCaption()
                    .padding(.horizontal, 8)
                    .transition(.opacity)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: title)
            }

            VStack(spacing: 12) {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: UUID()) // Ensures animation
            }
            .frame(maxWidth: .infinity)
            .themedCard()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: UUID())
    }
}
