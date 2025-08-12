//
//  AIWelcomeCard.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import SwiftUI

public struct AIWelcomeCard: View {
    @StateObject private var vm: AIWelcomeCardViewModel

    public init(vm: AIWelcomeCardViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    public var body: some View {
        Group {
            if let s = vm.suggestions.first {
                CardContent(suggestion: s)
            } else {
                EmptyStateCard()
            }
        }
        .themedCard(blurBackground: true)
        .redacted(reason: vm.isLoading ? .placeholder : [])
        .shimmer(active: vm.isLoading, speed: 1.0)
        .task { vm.load() }
        .animation(.snappy, value: vm.suggestions)
    }
}

private struct CardContent: View {
    let suggestion: AISuggestion
    @State private var showWhy = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(suggestion.title).font(.title3.bold())
                Text(suggestion.detail).font(.subheadline).foregroundStyle(.secondary)
                
                // 1–3 CTAs
                HStack(spacing: 8) {
                    ForEach(suggestion.ctas) { cta in
                        Button(cta.title) { cta.perform() }
                            .buttonStyle(.borderedProminent)
                            .clipShape(Capsule())
                    }
                }
                
                Button("Why this?") { showWhy = true }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .sheet(isPresented: $showWhy) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Why this suggestion").font(.headline)
                Text(suggestion.reason).font(.body)
                Spacer()
            }
            .padding()
        }
    }
}

private struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("All set for now ✨").font(.headline)
            Text("I’ll surface smart suggestions as your day evolves.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
