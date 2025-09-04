//
//  DebouncedExecutor.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/26/25.
//

import Foundation

/// A utility for executing debounced actions identified by unique keys.
public final class DebouncedExecutor {
    private let delay: TimeInterval
    private let queue: DispatchQueue
    private var workItems: [AnyHashable: DispatchWorkItem] = [:]
    private let lock = NSLock()
    
    public init(delay: TimeInterval = 0.5, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    /// Debounces an action associated with a unique identifier.
    /// If an action with the same ID is already pending, it will be canceled.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the action.
    ///   - action: The closure to execute.
    public func execute(id: AnyHashable, action: @escaping () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        // Cancel any existing task for this ID
        workItems[id]?.cancel()

        let item = DispatchWorkItem { [weak self] in
            self?.lock.lock()
            defer { self?.lock.unlock() }
            self?.workItems[id] = nil
            action()
        }

        workItems[id] = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Cancels a pending action for the given ID.
    public func cancel(id: AnyHashable) {
        lock.lock()
        defer { lock.unlock() }
        workItems[id]?.cancel()
        workItems[id] = nil
    }

    /// Immediately executes and removes the pending action for the given ID.
    public func flush(id: AnyHashable) {
        lock.lock()
        guard let item = workItems[id] else {
            lock.unlock()
            return
        }
        workItems[id] = nil
        lock.unlock()
        item.perform()
    }

    /// Cancels all pending actions.
    public func cancelAll() {
        lock.lock()
        defer { lock.unlock() }
        workItems.values.forEach { $0.cancel() }
        workItems.removeAll()
    }

    deinit {
        cancelAll()
    }
}
