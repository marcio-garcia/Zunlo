//
//  DefaultsSuggestionUsageStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/16/25.
//

import Foundation

// Tracks last-success timestamps per suggester (by telemetryKey).
public protocol SuggestionUsageStore {
    func lastSuccess(forTelemetryKey key: String) -> Date?
    func recordSuccess(forTelemetryKey key: String, at date: Date)
    func adjustedScore(base: Int, maxPenalty: Int, cooldown: TimeInterval, telemetryKey: String, now: Date) -> Int
}

// Simple UserDefaults-backed implementation (thread-safe).
public final class DefaultsSuggestionUsageStore: SuggestionUsageStore {
    private let defaults: UserDefaults
    private let prefix = "zunlo.suggestion.lastSuccess."
    // Concurrent queue + barrier writes for safety
    private let queue = DispatchQueue(label: "zunlo.DefaultsSuggestionUsageStore", qos: .userInitiated, attributes: .concurrent)

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func lastSuccess(forTelemetryKey key: String) -> Date? {
        let k = prefix + key
        return queue.sync {
            let t = defaults.double(forKey: k)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
    }

    public func recordSuccess(forTelemetryKey key: String, at date: Date) {
        let k = prefix + key
        queue.sync(flags: .barrier) {
            defaults.set(date.timeIntervalSince1970, forKey: k)
        }
    }

    // MARK: - Scoring

    public func adjustedScore(base: Int, maxPenalty: Int, cooldown: TimeInterval, telemetryKey: String, now: Date) -> Int {
        // Snapshot the last success under read lock to avoid races with concurrent writes.
        let last: Date? = queue.sync {
            let t = defaults.double(forKey: prefix + telemetryKey)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }

        guard let last else { return base }

        let dt = now.timeIntervalSince(last)
        if dt <= 0 { return max(0, base - maxPenalty) }
        if cooldown <= 0 { return base } // avoid div-by-zero; treat as no penalty window

        // Linear decay of penalty: right after success -> maxPenalty, then linearly goes to 0 at cooldown.
        let ratio = max(0.0, min(1.0, 1.0 - (dt / cooldown))) // 1 at t=0 -> 0 at t>=cooldown
        let penalty = Int(round(Double(maxPenalty) * ratio))
        return max(0, base - penalty)
    }
}

// If you need to pass this across Swift concurrency domains, you can opt into Sendable:
// extension DefaultsSuggestionUsageStore: @unchecked Sendable {}

