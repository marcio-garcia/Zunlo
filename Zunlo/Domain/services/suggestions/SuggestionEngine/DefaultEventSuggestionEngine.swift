//
//  DefaultEventSuggestionEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

import Foundation

final class DefaultEventSuggestionEngine: EventSuggestionEngine {
    let auth: AuthProviding
    let calendar: Calendar
    let eventFetcher: EventFetcherService
    let adjacencyMerges: Bool
    
    var policy: SuggestionPolicy
    
    init(
        auth: AuthProviding,
        calendar: Calendar,
        eventFetcher: EventFetcherService,
        policy: SuggestionPolicy,
        adjacencyMerges: Bool = true
    ) {
        self.auth = auth
        self.calendar = calendar
        self.eventFetcher = eventFetcher
        self.policy = policy
        self.adjacencyMerges = adjacencyMerges
    }

    public func freeWindows(on date: Date, minimumMinutes: Int) async -> [TimeWindow] {
        let ranges = utcAvailabilityRanges(for: date)
        guard !ranges.isEmpty else { return [] }

        let merged = await dayMergedBusyIntervals(on: date)
        var free: [TimeWindow] = []
        let minDur = TimeInterval(max(0, minimumMinutes) * 60)

        for r in ranges {
            var cursor = r.lowerBound
            for b in merged {
                if b.end <= r.lowerBound || b.start >= r.upperBound { continue }
                let bs = max(b.start, r.lowerBound)
                let be = min(b.end,   r.upperBound)
                if bs > cursor { free.append(TimeWindow(start: cursor, end: bs)) }
                cursor = max(cursor, be)
            }
            if cursor < r.upperBound { free.append(TimeWindow(start: cursor, end: r.upperBound)) }
        }
        return free.filter { $0.duration >= minDur }
    }

    // Returns the first busy-block start strictly AFTER `t`, within `date`'s day.
    public func nextEventStart(after t: Date, on date: Date) async -> Date? {
        let ranges = utcAvailabilityRanges(for: date)
        guard !ranges.isEmpty else { return nil }
        
        // If t is before first availability, start from that lower bound
        let earliestAvail = ranges.map(\.lowerBound).min()!
        let threshold = max(t, earliestAvail)
        
        let merged = await dayMergedBusyIntervals(on: date) // sorted
        // Lower-bound binary search for first start > threshold
        var lo = 0, hi = merged.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if merged[mid].start > threshold { hi = mid } else { lo = mid + 1 }
        }
        guard lo < merged.count else { return nil }
        let start = merged[lo].start
        // Ensure the start falls inside some availability range
        return ranges.contains(where: { $0.contains(start) }) ? start : nil
    }

    /// If you also count conflicts, don't treat adjacency as a conflict:
    /// sort tie-break: ends (-1) before starts (+1)
    public func conflictingItemsCount(on date: Date) async -> Int {
        let raw = await dayRawBusyIntervals(on: date, policy: policy)
        // Sweep-line, ends before starts at same instant => adjacency is not a conflict
        var pts: [(Date, Int)] = []
        pts.reserveCapacity(raw.count * 2)
        for i in raw { pts.append((i.start, +1)); pts.append((i.end, -1)) }
        pts.sort { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }

        var active = 0, overlaps = 0
        for (_, d) in pts {
            if d > 0 { if active > 0 { overlaps += active }; active += 1 }
            else { active -= 1 }
        }
        return overlaps
    }

    // MARK: helpers

    private func utcAvailabilityRanges(for date: Date) -> [Range<Date>] {
        var localCal = calendar
        localCal.timeZone = policy.availabilityTimeZone

        // Local start-of-day for the *target* date
        let localStartOfDay = localCal.startOfDay(for: date)
        let nextLocalMidnight = localStartOfDay.startOfNextDay(calendar: localCal)

        let startLocal = localCal.date(
            bySettingHour: policy.availabilityStartHour,
            minute: policy.availabilityStartMinute,
            second: 0,
            of: localStartOfDay
        )!
        var endLocal = localCal.date(
            bySettingHour: policy.availabilityEndHour,
            minute: policy.availabilityEndMinute,
            second: 0,
            of: localStartOfDay
        )!

        if endLocal == startLocal {
            endLocal = endLocal.startOfNextDay(calendar: localCal)
        }
        
        if endLocal > startLocal {
            // Single daytime window (e.g., 08:00–20:00 local)
            // adjust to current time
            let start = max(startLocal, date)
            // these Date values are absolute UTC instants
            return start > endLocal ? [] : [start..<endLocal]
        } else {
            // Overnight window (e.g., 22:00–06:00 local) -> split into two UTC ranges
            //   [00:00–endLocal] and [startLocal–24:00] in local time
            return [localStartOfDay..<endLocal, startLocal..<nextLocalMidnight]
        }
    }
    
    /// Clamp a single interval to a day range; drop if empty.
    private func clamp(_ i: BusyInterval, to r: Range<Date>) -> BusyInterval? {
        let s = max(i.start, r.lowerBound), e = min(i.end, r.upperBound)
        return s < e ? BusyInterval(start: s, end: e) : nil
    }

    // Build RAW busy intervals *clamped to the policy's availability windows for that day*.
    private func dayRawBusyIntervals(on date: Date, policy: SuggestionPolicy) async -> [BusyInterval] {
        guard await auth.isAuthorized(), let userId = auth.userId else { return [] }
        let ranges = utcAvailabilityRanges(for: date)
        guard !ranges.isEmpty else { return [] }

        var calendar = Calendar.appDefault
        calendar.timeZone = policy.availabilityTimeZone
        
        // TODO: replace with a ranged fetch. For now, fetchAll + clamp.
        let events = (try? await eventFetcher.fetchOccurrences(for: userId)) ?? []
        
        let today = date.startOfDay(calendar: calendar)
        let tomorrow = today.startOfNextDay(calendar: calendar)
        
        let occurrences = (try? EventOccurrenceService.generate(rawOccurrences: events, in: today..<tomorrow)) ?? []

        // Bound for open-ended events just to avoid huge spans; UTC calendar recommended.
        let utcDayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!

        var raw: [BusyInterval] = []
        raw.reserveCapacity(occurrences.count)

        for e in occurrences {
            let s = e.startDate.addingTimeInterval(-policy.padBefore)
            let eEnd = (e.endDate ?? utcDayEnd).addingTimeInterval(policy.padAfter)
            let bi = BusyInterval(start: s, end: eEnd)
            for r in ranges {
                if let clipped = clamp(bi, to: r) { raw.append(clipped) }
            }
        }
        return raw
    }
    
    /// Merged for the day with adjacency/gap absorption
    func dayMergedBusyIntervals(on date: Date) async -> [BusyInterval] {
        mergeBusy(await dayRawBusyIntervals(on: date, policy: policy),
                  absorbGapsBelow: policy.absorbGapsBelow)
    }
    
    /// Merge overlaps and absorb small gaps: it.start <= cur.end + absorb
    private func mergeBusy(_ intervals: [BusyInterval], absorbGapsBelow: TimeInterval) -> [BusyInterval] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.start < $1.start }
        var out: [BusyInterval] = []
        var cur = sorted[0]
        for it in sorted.dropFirst() {
            if it.start <= cur.end.addingTimeInterval(absorbGapsBelow) {
                cur = .init(start: cur.start, end: max(cur.end, it.end))
            } else { out.append(cur); cur = it }
        }
        out.append(cur)
        return out
    }
    
    private func sweepOverlaps(_ intervals: [BusyInterval]) -> Int {
        var points: [(Date, Int)] = []
        points.reserveCapacity(intervals.count * 2)
        for i in intervals { points.append((i.start, +1)); points.append((i.end, -1)) }
        points.sort { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 } // end before start at same time
        var active = 0, overlaps = 0
        for (_, d) in points {
            if d > 0 { if active > 0 { overlaps += active }; active += 1 }
            else { active -= 1 }
        }
        return overlaps
    }
}
