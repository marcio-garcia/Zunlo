//
//  AIContextBuilder.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

public class AIContextBuilder {
//    static func build(
//        time: TimeProvider,
//        policyProcider: SuggestionPolicyProvider,
//        tasks: TaskSuggestionEngine,
//        events: EventSuggestionEngine,
//        weather: WeatherProvider?
//    ) async -> AIContext {
//        let now = time.now
//        let cal = time.calendar
//        let dayStart = cal.startOfDay(for: now)
//        let dayEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: dayStart)!
//        
//        async let overdue = tasks.overdueCount(on: now)
//        async let dueToday = tasks.dueTodayCount(on: now)
//        async let highPrio = tasks.highPriorityCount(on: now)
//        async let topUnscheduled = tasks.topUnscheduled(limit: 5)
//        async let windows = events.freeWindows(on: now, minimumMinutes: 30)
//        async let nextStart = events.nextEventStart(after: now, on: now)
//        async let conflicts = events.conflictingItemsCount(on: now)
//        async let typicalStart = tasks.typicalStartTimeComponents()
//
//        var weatherSummary: String? = nil
//        var precip: Double? = nil
//        var rainingSoon = false
//        if let weather {
//            let w = await weather.summaryForToday()
//            weatherSummary = w.summary
//            precip = w.precipNext4h
//            rainingSoon = w.rainingSoon
//        }
//
//        let free = await windows
//        let longest = free.max(by: { $0.duration < $1.duration })
//
//        let policy = await policyProcider.policy
//        
//        return AIContext(
//            now: now,
//            dayStart: dayStart,
//            dayEnd: dayEnd,
//            period: period(for: now, calendar: cal),
//            nextEventStart: await nextStart,
//            freeWindows: free,
//            longestFreeWindow: longest,
//            minFocusDuration: policy.minFocusDuration,
//            overdueCount: await overdue,
//            dueTodayCount: await dueToday,
//            highPriorityCount: await highPrio,
//            topUnscheduledTasks: await topUnscheduled,
//            typicalStartTime: await typicalStart,
//            weatherSummary: weatherSummary,
//            precipitationChanceNext4h: precip,
//            isRainingSoon: rainingSoon,
//            conflictingItemsCount: await conflicts
//        )
//    }
//
//    private static func period(for date: Date, calendar: Calendar) -> DayPeriod {
//        let h = calendar.component(.hour, from: date)
//        switch h {
//        case 5..<9:   return .earlyMorning
//        case 9..<12:  return .morning
//        case 12..<17: return .afternoon
//        case 17..<22: return .evening
//        default:      return .lateNight
//        }
//    }
    
    /// Builds an AIContext for an arbitrary date range. For backward compatibility, `dayStart`/`dayEnd` in `AIContext`
    /// will be set to `rangeStart`/`rangeEnd`.
    func build(
        userId: UUID,
        time: TimeProvider,
        policyProvider: SuggestionPolicyProvider,
        tasks: TaskSuggestionEngine,
        events: EventSuggestionEngine,
        weather: WeatherProvider?,
        rangeStart rawStart: Date,
        rangeEnd rawEnd: Date,
        minimumWindowMinutes: Int = 30
    ) async -> AIContext {

        let cal = time.calendar
        // Normalize and guard the range (allow callers to pass inverted bounds)
        let interval = normalizedInterval(start: rawStart, end: rawEnd)

        // Anchor is used for things that are "point-in-time" (e.g., period, next event, overdue).
        // If the range includes "now", anchor at now; otherwise anchor at the nearest bound.
        let now = time.now
        let anchor = clamp(now, to: interval)

        // Eagerly compute the list of day starts in the range (local calendar days)
        let days = daysInInterval(interval, calendar: cal)

        // Independent stuff we can fetch in parallel up front.
        async let policy = policyProvider.policy
        async let topUnscheduled = tasks.topUnscheduled(limit: 5)
        async let typicalStart = tasks.typicalStartTimeComponents()

        // -------- Tasks (range-aware) --------

        // Overdue is relative to a single instant in time. We use the "anchor" so:
        // - if the interval includes today, it's "overdue as of now"
        // - if the interval is in the past/future, it's "overdue as of the closest bound"
        async let overdue = tasks.overdueCount(on: anchor)

        // Sum per-day counts across the interval in parallel.
        async let dueInRange: Int = withTaskGroup(of: Int.self, returning: Int.self) { group in
            for day in days { group.addTask { await tasks.dueTodayCount(on: day) } }
            var total = 0
            for await n in group { total += n }
            return total
        }

        async let highPrioInRange: Int = withTaskGroup(of: Int.self, returning: Int.self) { group in
            for day in days { group.addTask { await tasks.highPriorityCount(on: day) } }
            var total = 0
            for await n in group { total += n }
            return total
        }

        // -------- Events (range-aware) --------

        // Free windows per-day, flattened, clipped to the interval, and longest computed.
        let (freeWindowsAll, longestWindow) = await aggregateFreeWindows(
            events: events,
            days: days,
            interval: interval,
            minimumMinutes: minimumWindowMinutes
        )

        // Next event start after "anchor" but within the interval.
        async let nextStart: Date? = {
            await nextEventStartInRange(
                events: events,
                days: days,
                calendar: cal,
                anchor: anchor,
                interval: interval
            )
        }()

        // Total conflicts across the range (sum per day, in parallel).
        async let conflicts: Int = withTaskGroup(of: Int.self, returning: Int.self) { group in
            for day in days { group.addTask { await events.conflictingItemsCount(on: day) } }
            var total = 0
            for await n in group { total += n }
            return total
        }

        // -------- Weather (best-effort, aggregated) --------
        // If your WeatherProvider only supports "today", we only populate when the range includes today.
        // You can later extend WeatherProvider to support by-date summaries and this code will automatically aggregate.
        let (weatherSummary, precip, rainingSoon) = await aggregateWeather(
            weather: weather,
            calendar: cal,
            interval: interval
        )

        // -------- Compose AIContext --------

        return AIContext(
            userId: userId,
            now: now,
            dayStart: interval.start,
            dayEnd: interval.end,
            period: period(for: anchor, calendar: cal),                 // period for the anchor instant
            nextEventStart: await nextStart,
            freeWindows: freeWindowsAll,
            longestFreeWindow: longestWindow,
            minFocusDuration: await policy.minFocusDuration,
            overdueCount: await overdue,
            dueTodayCount: await dueInRange,                             // "due in range" (sum of per-day "due today")
            highPriorityCount: await highPrioInRange,                    // "high-priority in range" (sum per day)
            topUnscheduledTasks: await topUnscheduled,
            typicalStartTime: await typicalStart,
            weatherSummary: weatherSummary,
            precipitationChanceNext4h: precip,
            isRainingSoon: rainingSoon,
            conflictingItemsCount: await conflicts
        )
    }

    // MARK: - Backward-compatible single-day overload

    /// Keeps your original call sites working. This builds a range for the given `date`'s calendar day.
    func build(
        userId: UUID,
        time: TimeProvider,
        policyProvider: SuggestionPolicyProvider,
        tasks: TaskSuggestionEngine,
        events: EventSuggestionEngine,
        weather: WeatherProvider?,
        on date: Date
    ) async -> AIContext {
        let cal = time.calendar
        let dayStart = cal.startOfDay(for: date)
        // End inclusive(ish) like your original code; if you prefer a real end-of-day boundary, adjust to start of next day minus 1 second.
        let dayEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: dayStart)!
        return await build(
            userId: userId,
            time: time,
            policyProvider: policyProvider,
            tasks: tasks,
            events: events,
            weather: weather,
            rangeStart: dayStart,
            rangeEnd: dayEnd
        )
    }

    // MARK: - Helpers

    private func normalizedInterval(start: Date, end: Date) -> DateInterval {
        start <= end ? DateInterval(start: start, end: end) : DateInterval(start: end, end: start)
    }

    private func clamp(_ date: Date, to interval: DateInterval) -> Date {
        if date < interval.start { return interval.start }
        if date > interval.end { return interval.end }
        return date
    }

    /// Enumerates local day starts inside the interval (inclusive of start's day and end's day when appropriate).
    private func daysInInterval(_ interval: DateInterval, calendar: Calendar) -> [Date] {
        var days: [Date] = []
        var cursor = calendar.startOfDay(for: interval.start)
        let lastDay = calendar.startOfDay(for: interval.end)

        while cursor <= lastDay {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    /// Clips a `DateInterval` to another interval; returns nil if no intersection.
    private func clipped(_ interval: DateInterval, to container: DateInterval) -> DateInterval? {
        let start = max(interval.start, container.start)
        let end = min(interval.end, container.end)
        return start < end ? DateInterval(start: start, end: end) : nil
    }

    // MARK: - Events aggregation

    private func aggregateFreeWindows(
        events: EventSuggestionEngine,
        days: [Date],
        interval: DateInterval,
        minimumMinutes: Int
    ) async -> (all: [TimeWindow], longest: TimeWindow?) {
        // Fetch per-day in parallel
        let perDay: [[TimeWindow]] = await withTaskGroup(of: [TimeWindow].self, returning: [[TimeWindow]].self) { group in
            for day in days {
                group.addTask { await events.freeWindows(on: day, minimumMinutes: minimumMinutes) }
            }
            var all: [[TimeWindow]] = []
            for await windows in group { all.append(windows) }
            return all
        }

        // Flatten and clip to the requested range to avoid spillover beyond ends.
        let flattened = perDay.flatMap { $0 }
            .compactMap { fw -> TimeWindow? in
                guard let clippedInterval = clipped(fw.dateInterval(), to: interval) else { return nil }
                return TimeWindow(start: clippedInterval.start, end: clippedInterval.end)
            }
            .sorted { $0.start < $1.start }

        let longest = flattened.max(by: { $0.duration < $1.duration })
        return (flattened, longest)
    }

    private func nextEventStartInRange(
        events: EventSuggestionEngine,
        days: [Date],
        calendar: Calendar,
        anchor: Date,
        interval: DateInterval
    ) async -> Date? {
        // We only need to check days from the anchor's day onward.
        let anchorDay = calendar.startOfDay(for: anchor)
        let futureDays = days.filter { $0 >= anchorDay }

        var candidates: [Date] = []

        await withTaskGroup(of: Date?.self) { group in
            for day in futureDays {
                group.addTask {
                    let after = (calendar.isDate(day, inSameDayAs: anchorDay)) ? anchor : day
                    return await events.nextEventStart(after: after, on: day)
                }
            }
            for await d in group {
                if let d, interval.contains(d) { candidates.append(d) }
            }
        }

        return candidates.min()
    }

    // MARK: - Weather aggregation

    private func aggregateWeather(
        weather: WeatherProvider?,
        calendar: Calendar,
        interval: DateInterval
    ) async -> (summary: String?, precipNext4h: Double?, rainingSoon: Bool) {
        guard let weather else { return (nil, nil, false) }

        // Best-effort default: if the provider only supports "today", populate only when the range includes today.
        // If you extend WeatherProvider with date-based summaries later, switch this to iterate days and merge.
        if calendar.isDateInToday(interval.start) || calendar.isDateInToday(interval.end) {
            let w = await weather.summaryForToday()
            return (w.summary, w.precipNext4h, w.rainingSoon)
        } else {
            return (nil, nil, false)
        }
    }

    // MARK: - Your existing DayPeriod helper (unchanged)

    private func period(for date: Date, calendar: Calendar) -> DayPeriod {
        let h = calendar.component(.hour, from: date)
        switch h {
        case 5..<9:   return .earlyMorning
        case 9..<12:  return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default:      return .lateNight
        }
    }
}
