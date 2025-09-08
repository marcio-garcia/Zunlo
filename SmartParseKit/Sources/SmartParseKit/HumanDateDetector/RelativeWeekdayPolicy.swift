//
//  RelativeWeekdayPolicy.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/8/25.
//

import Foundation

/// Policies for relative weekday phrases.
public struct RelativeWeekdayPolicy {
    public enum ThisPolicy {
        /// Resolve to the nearest upcoming occurrence, including today if it matches.
        case upcomingIncludingToday
        /// Resolve to the nearest upcoming occurrence, but never today (must be in the future).
        case upcomingExcludingToday
    }

    public enum NextPolicy {
        /// Resolve to the next occurrence (no forced 7-day skip).
        case immediateUpcoming
        /// Resolve to the occurrence after the next (always skip one full week).
        case skipOneWeek
    }

    public var this: ThisPolicy
    public var next: NextPolicy
    
    /// Default duration for single-time matches (e.g., "wed 9") — tune as you like.
    public let defaultSingleDuration: TimeInterval
    
    public init(
        this: ThisPolicy = .upcomingExcludingToday,
        next: NextPolicy = .immediateUpcoming,
        defaultSingleDuration: TimeInterval = 0
    ) {
        self.this = this
        self.next = next
        self.defaultSingleDuration = defaultSingleDuration
    }
}
