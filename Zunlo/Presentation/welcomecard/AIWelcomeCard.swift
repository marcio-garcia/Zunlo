//
//  AIWelcomeCard.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import SwiftUI
import GlowUI

public struct AIWelcomeCard: View {
    @StateObject private var vm: AIWelcomeCardViewModel
    @EnvironmentObject var toolStore: ToolExecutionStore
    
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
    @EnvironmentObject var toolStore: ToolExecutionStore
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(suggestion.title)
                    .themedBody()
                Text(suggestion.detail)
                    .themedCallout()
                
                // 1–3 CTAs
                HStack(spacing: 8) {
                    ForEach(suggestion.ctas) { cta in
                        Button(cta.title) {
                            cta.perform(using: toolStore)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(Color.theme.accent)
                        .foregroundColor(.white)
                        .font(AppFontStyle.caption.font())
                        .cornerRadius(8)
                    }
                }
                
                Button("Why this?") { showWhy = true }
                    .themedFootnote()
            }
            Spacer()
        }
        .sheet(isPresented: $showWhy) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Why this suggestion").themedHeadline()
                Text(suggestion.reason).themedBody()
                Spacer()
            }
            .padding()
        }
    }
}

private struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("All set for now ✨")
                .themedHeadline()
            Text("I’ll surface smart suggestions as your day evolves.")
                .themedBody()
        }
    }
}
