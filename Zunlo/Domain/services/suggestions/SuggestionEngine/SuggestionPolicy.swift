//
//  SuggestionPolicy.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

import Foundation

struct AvailabilityPrefs: Equatable {
    var startHour: Int = 8
    var startMinute: Int = 0
    var endHour: Int = 20
    var endMinute: Int = 0
    var timeZoneID: String = TimeZone.current.identifier

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .gmt }
}

// MARK: - SuggestionPolicy mirror (local window + timezone)

public struct SuggestionPolicy: Sendable, Equatable {
    public var absorbGapsBelow: TimeInterval = 0     // merge tiny gaps (0 => only adjacency)
    public var padBefore: TimeInterval = 0           // pre-buffer (travel/setup)
    public var padAfter:  TimeInterval = 0           // post-buffer (cleanup/travel)

    // Availability interpreted in `availabilityTimeZone` *per local day*
    public var availabilityStartHour: Int = 8
    public var availabilityStartMinute: Int = 0
    public var availabilityEndHour: Int = 20
    public var availabilityEndMinute: Int = 0
    public var availabilityTimeZone: TimeZone       // e.g. TimeZone(identifier: "America/Sao_Paulo")!

    public init(absorbGapsBelow: TimeInterval = 0,
                padBefore: TimeInterval = 0,
                padAfter: TimeInterval = 0,
                availabilityStartHour: Int = 8,
                availabilityStartMinute: Int = 0,
                availabilityEndHour: Int = 20,
                availabilityEndMinute: Int = 0,
                availabilityTimeZone: TimeZone = .gmt) {
        self.absorbGapsBelow = absorbGapsBelow
        self.padBefore = padBefore
        self.padAfter = padAfter
        self.availabilityStartHour = availabilityStartHour
        self.availabilityStartMinute = availabilityStartMinute
        self.availabilityEndHour = availabilityEndHour
        self.availabilityEndMinute = availabilityEndMinute
        self.availabilityTimeZone = availabilityTimeZone
    }
}

extension SuggestionPolicy {
    static func from(_ p: AvailabilityPrefs,
                     absorbGapsBelow: TimeInterval = 15*60,
                     padBefore: TimeInterval = 5*60,
                     padAfter: TimeInterval = 5*60) -> SuggestionPolicy {
        SuggestionPolicy(
            absorbGapsBelow: absorbGapsBelow,
            padBefore: padBefore,
            padAfter: padAfter,
            availabilityStartHour: p.startHour,
            availabilityStartMinute: p.startMinute,
            availabilityEndHour: p.endHour,
            availabilityEndMinute: p.endMinute,
            availabilityTimeZone: p.timeZone
        )
    }
}

// Ship this as your app-wide default
extension SuggestionPolicy {
    /// Balanced, daytime-only policy that works well for most users.
    static func defaultForApp(timeZone: TimeZone = .current) -> SuggestionPolicy {
        SuggestionPolicy(
            // Swallow tiny slivers so you don't suggest unusable 5–10 min gaps.
            absorbGapsBelow: 15 * 60,          // 15 minutes

            // Keep suggestions from butting right up against meetings.
            padBefore: 5 * 60,                 // 5 minutes
            padAfter:  5 * 60,                 // 5 minutes

            // “Daytime” by default; users can change these in Settings.
            availabilityStartHour: 8,          // 08:00 local
            availabilityStartMinute: 0,
            availabilityEndHour: 20,           // 20:00 local
            availabilityEndMinute: 0,

            // Interpret availability in the user's local zone (storage stays UTC).
            availabilityTimeZone: timeZone
        )
    }
}

extension SuggestionPolicy {
    static func deepFocus(timeZone: TimeZone = .current) -> SuggestionPolicy {
        var p = defaultForApp(timeZone: timeZone)
        p.absorbGapsBelow = 30 * 60     // swallow <30m gaps -> fewer, larger blocks
        p.padBefore = 10 * 60; p.padAfter = 10 * 60
        return p
    }

    static func onSiteTravel(timeZone: TimeZone = .current) -> SuggestionPolicy {
        var p = defaultForApp(timeZone: timeZone)
        p.absorbGapsBelow = 20 * 60
        p.padBefore = 10 * 60; p.padAfter = 10 * 60
        return p
    }

    static func nightShift(timeZone: TimeZone = .current) -> SuggestionPolicy {
        var p = defaultForApp(timeZone: timeZone)
        p.availabilityStartHour = 22
        p.availabilityEndHour = 6        // overnight window handled by your converter
        return p
    }
}
