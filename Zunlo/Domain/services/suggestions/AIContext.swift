//
//  AIContext.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

/// A simple time window type (half-open interval).
public struct TimeWindow: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public var duration: TimeInterval { end.timeIntervalSince(start) }
    
    /// Pick the best duration from allowed options that fits in this window.
    func bestFit(minutes options: [Int]) -> Int {
        let avail = Int(duration / 60)
        return options.filter { $0 <= avail }.max() ?? options.min() ?? 15
    }
}

/// High-level day period used for copy & heuristics.
public enum DayPeriod: String, Sendable {
    case earlyMorning, morning, afternoon, evening, lateNight
}

public struct AITuning: Sendable, Equatable {
    public var typicalFocusDurations: [Int] = [15, 25, 45]
    public var minWindowMinutes: Int = 10
    public init() {}
}

/// Snapshot of “what matters right now” for AI suggestions.
public struct AIContext: Sendable {
    public let now: Date
    public let dayStart: Date
    public let dayEnd: Date
    public let period: DayPeriod
    
    // Calendar windows
    public let nextEventStart: Date?
    public let freeWindows: [TimeWindow]          // sorted, today, ≥ 10 min
    public let longestFreeWindow: TimeWindow?
    
    // Tasks summary
    public let overdueCount: Int
    public let dueTodayCount: Int
    public let highPriorityCount: Int
    public let topUnscheduledTasks: [UserTask]    // 0–5 tasks
    
    // Heuristics
    public let typicalStartTime: DateComponents?  // e.g., 9:00 for “start day” habits
    
    // Weather (optional; fill from your provider)
    public let weatherSummary: String?
    public let precipitationChanceNext4h: Double? // 0…1
    public let isRainingSoon: Bool

    // Conflicts detected today (simple count for v1)
    public let conflictingItemsCount: Int
}

public extension AIContext {
    /// First free window strictly after `now`.
    var nextWindow: TimeWindow? {
        freeWindows.first { $0.start > now }
    }

    /// Choose a reasonable focus duration for the next window from allowed options.
    func bestFocusDuration(tuning: AITuning = .init()) -> Int {
        guard let w = nextWindow else { return tuning.typicalFocusDurations.first ?? 15 }
        return w.bestFit(minutes: tuning.typicalFocusDurations)
    }
}

// Convenience over context to pick candidate tasks
public extension AIContext {
    /// Top ranked candidates from your snapshot's `topUnscheduledTasks`.
    /// If you keep `topUnscheduledTasks` internal, expose a public getter or mirror it into this extension.
    var rankedCandidates: [UserTask] {
        TaskScorer.rank(topUnscheduledTasks, now: now)
    }

    /// Best candidate for the next window (simple version; you can refine with estimates later).
    var bestCandidateForNextWindow: UserTask? {
        rankedCandidates.first
    }
}
