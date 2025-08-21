//
//  DebouncedExecutor.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/26/25.
//

import Foundation

/// A utility for executing debounced actions identified by unique keys.
public actor DebouncedExecutor {
    public let delay: TimeInterval
    public let queue: DispatchQueue

    // Pending entries
    private var syncEntries:  [AnyHashable: SyncEntry]  = [:]
    private var asyncEntries: [AnyHashable: AsyncEntry] = [:]

    public init(delay: TimeInterval = 0.5, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    // MARK: - SYNC (non-async closure, executed on `queue`)

    /// Debounce a synchronous action. After the delay elapses without a new call,
    /// the action runs on `queue`.
    /// If an action with the same ID is already pending, it will be canceled.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the action.
    ///   - action: The closure to execute.
    public func execute(id: AnyHashable, action: @escaping @Sendable () -> Void) {
        // Cancel any existing pending task for this id
        syncEntries[id]?.task.cancel()

        let nanos = UInt64(delay * 1_000_000_000)
        
        let task: Task<Void, Never> = Task { [queue] in
            try? await Task.sleep(nanoseconds: nanos)
            if Task.isCancelled { self.removeSync(id: id)}
            
            queue.async { action() }      // hop to the desired queue
            
            self.removeSync(id: id)     // cleanup
        }

        syncEntries[id] = SyncEntry(action: action, task: task)
    }

    // MARK: - ASYNC (async closure)

    /// Debounce an async action. After the delay elapses without a new call,
    /// the async action is awaited.
    public func execute(id: AnyHashable, action: @escaping @Sendable () async -> Void) {
        asyncEntries[id]?.task.cancel()

        let nanos = UInt64(delay * 1_000_000_000)
        
        let task: Task<Void, Never> = Task {
            try? await Task.sleep(nanoseconds: nanos)
            if Task.isCancelled { self.removeAsync(id: id) }
            
            await action()
                
            self.removeAsync(id: id)    // cleanup
        }

        asyncEntries[id] = AsyncEntry(action: action, task: task)
    }

    /// Convenience for UI work that must run on the main actor.
    public func executeOnMain(id: AnyHashable, action: @escaping @MainActor () async -> Void) {
        execute(id: id) { await action() }    // auto-hops to MainActor when executed
    }

    // MARK: - Flush / Cancel

    /// Immediately run and remove the pending sync action for `id`.
    public func flush(id: AnyHashable) {
        guard let entry = syncEntries.removeValue(forKey: id) else { return }
        entry.task.cancel()
        queue.async { entry.action() }
    }

    /// Immediately run and remove the pending async action for `id`.
    public func flushAsync(id: AnyHashable) {
        guard let entry = asyncEntries.removeValue(forKey: id) else { return }
        entry.task.cancel()
        Task { await entry.action() }
    }

    /// Cancel (and remove) any pending action for `id` (sync or async).
    public func cancel(id: AnyHashable) {
        syncEntries[id]?.task.cancel()
        syncEntries[id] = nil
        asyncEntries[id]?.task.cancel()
        asyncEntries[id] = nil
    }

    /// Cancel all pending actions.
    public func cancelAll() {
        for entry in syncEntries.values  { entry.task.cancel() }
        for entry in asyncEntries.values { entry.task.cancel() }
        syncEntries.removeAll()
        asyncEntries.removeAll()
    }

    deinit {
        // Best-effort cancellation (can't `await` in deinit)
        for entry in syncEntries.values  { entry.task.cancel() }
        for entry in asyncEntries.values { entry.task.cancel() }
    }

    // MARK: - Internals

    private func removeSync(id: AnyHashable)  { syncEntries[id]  = nil }
    private func removeAsync(id: AnyHashable) { asyncEntries[id] = nil }

    private struct SyncEntry {
        let action: @Sendable () -> Void
        let task: Task<Void, Never>
    }

    private struct AsyncEntry {
        let action: @Sendable () async -> Void
        let task: Task<Void, Never>
    }
}

///// A utility for executing debounced actions identified by unique keys.
//public final class DebouncedExecutor {
//    private let delay: TimeInterval
//    private let queue: DispatchQueue
//    private var workItems: [AnyHashable: DispatchWorkItem] = [:]
//    private let lock = NSLock()
//    
//    public init(delay: TimeInterval = 0.5, queue: DispatchQueue = .main) {
//        self.delay = delay
//        self.queue = queue
//    }
//
//    /// Debounces an action associated with a unique identifier.
//    /// If an action with the same ID is already pending, it will be canceled.
//    ///
//    /// - Parameters:
//    ///   - id: A unique identifier for the action.
//    ///   - action: The closure to execute.
//    public func execute(id: AnyHashable, action: @escaping () -> Void) {
//        lock.lock()
//        defer { lock.unlock() }
//
//        // Cancel any existing task for this ID
//        workItems[id]?.cancel()
//
//        let item = DispatchWorkItem { [weak self] in
//            self?.lock.lock()
//            defer { self?.lock.unlock() }
//            self?.workItems[id] = nil
//            action()
//        }
//
//        workItems[id] = item
//        queue.asyncAfter(deadline: .now() + delay, execute: item)
//    }
//
//    /// Cancels a pending action for the given ID.
//    public func cancel(id: AnyHashable) {
//        lock.lock()
//        defer { lock.unlock() }
//        workItems[id]?.cancel()
//        workItems[id] = nil
//    }
//
//    /// Immediately executes and removes the pending action for the given ID.
//    public func flush(id: AnyHashable) {
//        lock.lock()
//        guard let item = workItems[id] else {
//            lock.unlock()
//            return
//        }
//        workItems[id] = nil
//        lock.unlock()
//        item.perform()
//    }
//
//    /// Cancels all pending actions.
//    public func cancelAll() {
//        lock.lock()
//        defer { lock.unlock() }
//        workItems.values.forEach { $0.cancel() }
//        workItems.removeAll()
//    }
//
//    deinit {
//        cancelAll()
//    }
//}
