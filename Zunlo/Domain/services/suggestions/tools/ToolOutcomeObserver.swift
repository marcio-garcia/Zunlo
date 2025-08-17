//
//  ToolOutcomeObserver.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/17/25.
//

import SwiftUI

// MARK: - Generic observer (drain + live subscribe)

struct ToolOutcomeObserver: ViewModifier {
    @EnvironmentObject private var store: ToolExecutionStore
    @State private var outcomeTask: Task<Void, Never>?

    /// Called on the main actor for drained and live events.
    let onEvents: @MainActor ([ToolOutcomeEvent]) -> Void
    /// Optional filter (by run kind). If nil, all events pass.
    let includeKind: ((ToolKind) -> Bool)?

    func body(content: Content) -> some View {
        content
            .onAppear {
                // 1) Drain anything that completed while we were away
                let drained = store.drainPendingOutcomes().filter { e in
                    guard let kind = store.runs[e.runID]?.kind else { return true }
                    return includeKind?(kind) ?? true
                }
                onEvents(drained)

                // 2) Subscribe to live outcomes
                outcomeTask?.cancel()
                outcomeTask = Task { @MainActor in
                    for await e in store.outcomeEvents() {
                        if let includeKind, let kind = store.runs[e.runID]?.kind, includeKind(kind) == false {
                            continue
                        }
                        onEvents([e])
                    }
                }
            }
            .onDisappear { outcomeTask?.cancel() }
    }
}

extension View {
    /// Observe ToolExecutionStore outcomes (drains queue + listens live).
    /// - Parameters:
    ///   - includeKind: (optional) filter by `ToolKind`
    ///   - onEvents: handler invoked on main actor
    func observeToolOutcomes(
        includeKind: ((ToolKind) -> Bool)? = nil,
        onEvents: @escaping @MainActor ([ToolOutcomeEvent]) -> Void
    ) -> some View {
        modifier(ToolOutcomeObserver(onEvents: onEvents, includeKind: includeKind))
    }
}
