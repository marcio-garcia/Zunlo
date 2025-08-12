//
//  LegacySuggestionEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

// MARK: - ORIGINAL (Legacy) implementation under test

import Foundation
@testable import Zunlo

final class LegacySuggestionEngine {
    let calendar: Calendar
    let store: EventLocalStore

    init(calendar: Calendar, store: EventLocalStore) {
        self.calendar = calendar
        self.store = store
    }

    public func freeWindows(on date: Date, minimumMinutes: Int) async -> [TimeWindow] {
        let day = calendar.dayRange(containing: date)
        let busy = await busyIntervals(on: date)
            .map { BusyInterval(start: max($0.start, day.lowerBound), end: min($0.end, day.upperBound)) }
            .filter { $0.start < $0.end }

        let merged = mergeOverlaps(busy)

        var free: [TimeWindow] = []
        var cursor = day.lowerBound
        for b in merged {
            if b.start > cursor { free.append(TimeWindow(start: cursor, end: b.start)) }
            cursor = max(cursor, b.end)
        }
        if cursor < day.upperBound { free.append(TimeWindow(start: cursor, end: day.upperBound)) }

        let minDur = TimeInterval(minimumMinutes * 60)
        return free.filter { $0.duration >= minDur }
    }

    public func nextEventStart(after: Date, on date: Date) async -> Date? {
        let day = calendar.dayRange(containing: date)
        return await busyIntervals(on: date)
            .map { BusyInterval(start: max($0.start, day.lowerBound), end: min($0.end, day.upperBound)) }
            .filter { $0.start > after }
            .sorted { $0.start < $1.start }
            .first?.start
    }

    public func conflictingItemsCount(on date: Date) async -> Int {
        let intervals = await busyIntervals(on: date).sorted { $0.start < $1.start }
        var conflicts = 0
        var currentEnd: Date? = nil
        for i in intervals {
            if let e = currentEnd, i.start < e {
                conflicts += 1
                currentEnd = max(e, i.end)
            } else {
                currentEnd = i.end
            }
        }
        return conflicts
    }

    private func busyIntervals(on date: Date) async -> [BusyInterval] {
        let day = calendar.dayRange(containing: date)
        do {
            let events = try await store.fetchAll()
            // NOTE: tasks not included in this original version
            let raw = events
                .filter { ($0.endDate ?? day.upperBound) >= day.lowerBound && $0.startDate <= day.upperBound }
                .map { BusyInterval(start: $0.startDate, end: ($0.endDate ?? day.upperBound)) }
            return mergeOverlaps(raw)
        } catch {
            return []
        }
    }

    private func mergeOverlaps(_ intervals: [BusyInterval]) -> [BusyInterval] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.start < $1.start }
        var out: [BusyInterval] = []
        var cur = sorted[0]
        for it in sorted.dropFirst() {
            if it.start <= cur.end { // adjacency merges
                cur = BusyInterval(start: cur.start, end: max(cur.end, it.end))
            } else {
                out.append(cur)
                cur = it
            }
        }
        out.append(cur)
        return out
    }
}
