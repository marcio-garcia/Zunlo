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
}

/// High-level day period used for copy & heuristics.
public enum DayPeriod: String, Sendable {
    case earlyMorning, morning, afternoon, evening, lateNight
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
    let topUnscheduledTasks: [UserTask]    // 0–5 tasks
    
    // Heuristics
    public let typicalStartTime: DateComponents?  // e.g., 9:00 for “start day” habits
    
    // Weather (optional; fill from your provider)
    public let weatherSummary: String?
    public let precipitationChanceNext4h: Double? // 0…1
    public let isRainingSoon: Bool

    // Conflicts detected today (simple count for v1)
    public let conflictingItemsCount: Int
}
