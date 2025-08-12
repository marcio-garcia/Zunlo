//
//  RoundedSection.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/21/25.
//

import SwiftUI

struct RoundedSection<Content: View, Footer: View>: View {
    var title: String?
    var content: () -> Content
    var footer: () -> Footer

    init(
        title: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.title = title
        self.content = content
        self.footer = footer
    }

    // Convenience initializer when you don't need a footer
    init(
        title: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) where Footer == EmptyView {
        self.title = title
        self.content = content
        self.footer = { EmptyView() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: UUID())
            }
            .frame(maxWidth: .infinity)
            .themedCard()

            // Footer is rendered below the card. When Footer == EmptyView, this takes no space.
            footer()
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .transition(.opacity)
                .animation(.spring(response: 0.5, dampingFraction: 0.9), value: UUID())
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: UUID())
    }
}
