//
//  ToolOutcomePresenter.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/17/25.
//

import SwiftUI
import GlowUI

struct ToolOutcomePresenter: ViewModifier {
    @EnvironmentObject private var store: ToolExecutionStore
    @Binding var toast: Toast?
    let includeKind: ((ToolKind) -> Bool)?
    let onNavigate: (@MainActor (ToolRoute) -> Void)?

    @State private var outcomeTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                handle(store.drainPendingOutcomes())
                outcomeTask?.cancel()
                outcomeTask = Task { @MainActor in
                    for await e in store.outcomeEvents() {
                        handle([e])
                    }
                }
            }
            .onDisappear { outcomeTask?.cancel() }
    }

    @MainActor
    private func handle(_ events: [ToolOutcomeEvent]) {
        for e in events {
            if let includeKind, let kind = store.runs[e.runID]?.kind, includeKind(kind) == false {
                continue
            }
            switch e.outcome {
            case .success:
                toast = Toast("Success ✅", duration: 3)

            case let .toast(message, duration):
                toast = Toast(message, duration: duration)

            case let .navigate(route):
                onNavigate?(route)
            }
        }
    }
}

extension View {
    /// Present tool outcomes with a toast and optional navigation hook.
    func presentToolOutcomes(
        toast: Binding<Toast?>,
        includeKind: ((ToolKind) -> Bool)? = nil,
        onNavigate: (@MainActor (ToolRoute) -> Void)? = nil
    ) -> some View {
        modifier(ToolOutcomePresenter(toast: toast, includeKind: includeKind, onNavigate: onNavigate))
    }
}
