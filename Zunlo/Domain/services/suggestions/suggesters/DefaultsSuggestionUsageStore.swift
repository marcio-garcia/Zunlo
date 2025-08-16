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

// Simple UserDefaults-backed implementation.
public final class DefaultsSuggestionUsageStore: SuggestionUsageStore {
    private let defaults: UserDefaults
    private let prefix = "zunlo.suggestion.lastSuccess."

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func lastSuccess(forTelemetryKey key: String) -> Date? {
        let k = prefix + key
        let t = defaults.double(forKey: k)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    public func recordSuccess(forTelemetryKey key: String, at date: Date) {
        let k = prefix + key
        defaults.set(date.timeIntervalSince1970, forKey: k)
    }
    
    // MARK: - Scoring

    public func adjustedScore(base: Int, maxPenalty: Int, cooldown: TimeInterval, telemetryKey: String, now: Date) -> Int {
        guard let last = lastSuccess(forTelemetryKey: telemetryKey) else {
            return base
        }
        let dt = now.timeIntervalSince(last)
        if dt <= 0 { return max(0, base - maxPenalty) }

        // Linear decay of penalty: right after success -> maxPenalty, then linearly goes to 0 at cooldown.
        let ratio = max(0.0, min(1.0, 1.0 - (dt / cooldown))) // 1 at t=0 -> 0 at t>=cooldown
        let penalty = Int(round(Double(maxPenalty) * ratio))
        return max(0, base - penalty)
    }
}
