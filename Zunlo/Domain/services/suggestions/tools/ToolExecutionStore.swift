//
//  ToolExecutionStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/16/25.
//

import SwiftUI

@MainActor
final public class ToolExecutionStore: ObservableObject, Sendable {
    @Published private(set) var runs: [UUID: ToolExecutionState] = [:]
    @Published private(set) var pendingOutcomes: [ToolOutcomeEvent] = []

    private var tasks: [UUID: Task<Void, Never>] = [:]

    // Multi-subscriber AsyncStream for live outcomes
    private var liveContinuations: [UUID: AsyncStream<ToolOutcomeEvent>.Continuation] = [:]

    func start(kind: ToolKind, status: String? = "Starting…") -> UUID {
        let id = UUID()
        runs[id] = .init(kind: kind, isRunning: true, progress: nil, status: status)
        return id
    }

    func attach(runID: UUID, task: Task<Void, Never>) {
        tasks[runID]?.cancel()
        tasks[runID] = task
    }

    func progress(_ runID: UUID, status: String?, fraction: Double?) {
        guard var s = runs[runID] else { return }
        s.status = status ?? s.status
        s.progress = fraction
        runs[runID] = s
    }

    func finish(_ runID: UUID, outcome: ToolOutcome) {
        guard var s = runs[runID] else { return }
        s.isRunning = false
        s.finishedAt = .init()
        runs[runID] = s
        let event = ToolOutcomeEvent(runID: runID, outcome: outcome)
        // Persist so late subscribers can handle it
        pendingOutcomes.append(event)
        // Also emit live for active subscribers
        broadcast(event)
        // Clean up task
        tasks[runID]?.cancel()
        tasks[runID] = nil
    }

    func fail(_ runID: UUID, error: String) {
        guard var s = runs[runID] else { return }
        s.isRunning = false
        s.error = error
        s.finishedAt = .init()
        runs[runID] = s
        let event = ToolOutcomeEvent(runID: runID, outcome: .toast("Failed: \(error)"))
        pendingOutcomes.append(event)
        broadcast(event)
        tasks[runID]?.cancel()
        tasks[runID] = nil
    }

    func cancel(_ runID: UUID) {
        tasks[runID]?.cancel()
        tasks[runID] = nil
        if var s = runs[runID] {
            s.isRunning = false
            s.status = "Cancelled"
            s.finishedAt = .init()
            runs[runID] = s
        }
    }

    /// Drains and returns all currently pending outcomes (so you can handle them once).
    @discardableResult
    func drainPendingOutcomes() -> [ToolOutcomeEvent] {
        let items = pendingOutcomes
        pendingOutcomes.removeAll()
        return items
    }

    /// Subscribe to live outcomes (in addition to the pending queue).
    func outcomeEvents() -> AsyncStream<ToolOutcomeEvent> {
        AsyncStream { continuation in
            let token = UUID()
            liveContinuations[token] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.liveContinuations.removeValue(forKey: token)
                }
            }
        }
    }

    private func broadcast(_ event: ToolOutcomeEvent) {
        for c in liveContinuations.values { c.yield(event) }
    }
}
