//
//  RecurrenceHelper.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/6/25.
//

import Foundation

enum RecurrenceFrequesncy: String, Codable {
    case daily
    case weekly
    case monthly
    case yearly
}

class RecurrenceHelper {
    
    /// Weekdays use Calendar convention: 1=Sunday, 2=Monday, ..., 7=Saturday.

    static func generateRecurrenceDates(
        start: Date,
        rule: RecurrenceRule,
        within range: Range<Date>,
        calendar: Calendar = .appDefault,
        eventTimeZone: TimeZone = .current
    ) -> [Date] {
        switch rule.freq {
        case .daily:
            return generateDailyRecurrence(start: start, rule: rule, within: range, calendar: calendar, eventTimeZone: eventTimeZone)
        case .weekly:
            return generateWeeklyRecurrence(start: start, rule: rule, within: range, calendar: calendar, eventTimeZone: eventTimeZone)
        case .monthly:
            return generateMonthlyRecurrence(start: start, rule: rule, within: range, calendar: calendar, eventTimeZone: eventTimeZone)
        case .yearly:
            return generateYearlyRecurrence(start: start, rule: rule, within: range, calendar: calendar, eventTimeZone: eventTimeZone)
        }
    }

    /// Generates all occurrence instants for a daily recurring event.
    /// - Parameters:
    ///   - startUTC: The first occurrence instant (stored in UTC).
    ///   - rule: Recurrence rule (interval in days; COUNT/UNTIL apply to all occurrences).
    ///   - rangeUTC: Only return occurrences that fall within this absolute time window (UTC instants).
    ///   - baseCalendar: A calendar to base calculations on (e.g., `.gregorian`); its timeZone will be overridden.
    ///   - eventTimeZone: The event’s local time zone in which the wall-clock time is defined.
    /// - Returns: Occurrence instants as `Date` values (absolute UTC instants).
    private static func generateDailyRecurrence(
        start startUTC: Date,
        rule: RecurrenceRule,
        within rangeUTC: Range<Date>,
        calendar baseCalendar: Calendar,
        eventTimeZone: TimeZone
    ) -> [Date] {
        // Work in the event's local zone so "time of day" means local wall time.
        var calendar = baseCalendar
        calendar.timeZone = eventTimeZone

        var dates: [Date] = []
        let interval = max(1, rule.interval)

        // Preserve full wall-clock time (incl. seconds/nanoseconds).
        let timeComps = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: startUTC)

        // UNTIL: treat as day-inclusive in the event's zone => exclusive boundary = startOfDay(until)+1 day.
        let untilExclusive: Date? = rule.until.flatMap {
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0))
        }
        if let until = untilExclusive, startUTC >= until { return [] }

        var occurrences = 0
        var candidate = startUTC

        while true {
            // Stop on UNTIL (exclusive boundary) before counting.
            if let until = untilExclusive, candidate >= until {
                break
            }

            // Count every valid occurrence (even if outside the requested return range).
            occurrences += 1

            // Add to output if within the requested window.
            if rangeUTC.contains(candidate) {
                if dates.last != candidate { dates.append(candidate) }
            }

            // Respect COUNT across all occurrences.
            if let count = rule.count, occurrences >= count {
                break
            }

            // Advance by N days, keeping the same local wall-clock time; handle DST holes/folds.
            guard let stepStart = calendar.date(byAdding: .day, value: interval, to: candidate) else { break }

            var comps = DateComponents()
            comps.hour = timeComps.hour
            comps.minute = timeComps.minute
            comps.second = timeComps.second
            comps.nanosecond = timeComps.nanosecond

            // Use nextDate to normalize to the intended local time on the target day.
            guard let next = calendar.nextDate(
                after: stepStart.addingTimeInterval(-1),
                matching: comps,
                matchingPolicy: .nextTimePreservingSmallerComponents,
                repeatedTimePolicy: .first,
                direction: .forward
            ) else {
                break
            }

            candidate = next

            // Early exit for open-ended series once we're past the query window.
            if rule.count == nil, untilExclusive == nil, candidate >= rangeUTC.upperBound {
                break
            }
        }

        return dates
    }

    /// Generates all occurrence instants for a weekly recurring event.
    /// - Parameters:
    ///   - startUTC: The first occurrence instant (stored in UTC).
    ///   - rule: Recurrence rule (Apple weekday numbering: Sunday=1…Saturday=7).
    ///   - rangeUTC: Only return occurrences that fall within this absolute time window (UTC instants).
    ///   - baseCalendar: A calendar to base calculations on (e.g., `.gregorian`); its timeZone will be overridden.
    ///   - eventTimeZone: The event’s local time zone in which weekday/time semantics are defined.
    /// - Returns: Occurrence instants as `Date` values (absolute UTC instants).
    private static func generateWeeklyRecurrence(
        start startUTC: Date,
        rule: RecurrenceRule,
        within rangeUTC: Range<Date>,
        calendar baseCalendar: Calendar,
        eventTimeZone: TimeZone
    ) -> [Date] {
        // Work in the event's local zone so "weekday @ time" means local wall time.
        var calendar = baseCalendar
        calendar.timeZone = eventTimeZone

        var dates: [Date] = []
        let interval = max(1, rule.interval)

        // Preserve full wall-clock time (incl. seconds/nanoseconds).
        let timeComps = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: startUTC)

        // Anchor week start (avoid force-unwrap).
        let weekAnchor = calendar.dateInterval(of: .weekOfYear, for: startUTC)?.start
            ?? calendar.startOfDay(for: startUTC)

        // UNTIL: treat as day-inclusive in the event's zone => exclusive boundary = startOfDay(until)+1 day.
        let untilExclusive: Date? = rule.until.flatMap {
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0))
        }
        // If the series ends before it begins, nothing to generate.
        if let until = untilExclusive, startUTC >= until { return [] }

        // Weekdays: default to the start's weekday when nil or empty; dedup and validate 1...7.
        let defaultWk = calendar.component(.weekday, from: startUTC)
        var weekdays = (rule.byWeekday?.isEmpty == false ? rule.byWeekday! : [defaultWk])
            .filter { (1...7).contains($0) }
        weekdays = Array(Set(weekdays))

        // Deterministic in-week ordering relative to the anchor week's weekday.
        let anchorWk = calendar.component(.weekday, from: weekAnchor)
        @inline(__always) func orderKey(_ wd: Int) -> Int { (wd - anchorWk + 7) % 7 }
        weekdays.sort { orderKey($0) < orderKey($1) }

        var weekStart = weekAnchor
        var occurrences = 0

        while true {
            for wd in weekdays {
                var comps = DateComponents()
                comps.weekday = wd
                comps.hour = timeComps.hour
                comps.minute = timeComps.minute
                comps.second = timeComps.second
                comps.nanosecond = timeComps.nanosecond

                // Use -1s so a candidate exactly at weekStart time is included.
                guard let candidate = calendar.nextDate(
                    after: weekStart.addingTimeInterval(-1),
                    matching: comps,
                    matchingPolicy: .nextTimePreservingSmallerComponents,
                    repeatedTimePolicy: .first,
                    direction: .forward
                ) else {
                    continue
                }

                // Respect series start.
                if candidate < startUTC { continue }

                // Respect UNTIL (exclusive boundary).
                if let until = untilExclusive, candidate >= until {
                    return dates
                }

                // Count every valid occurrence (even if outside the requested return range).
                occurrences += 1

                // Add to output if within the requested window.
                if rangeUTC.contains(candidate) {
                    if dates.last != candidate { dates.append(candidate) }
                }

                // Respect COUNT across all occurrences.
                if let count = rule.count, occurrences >= count {
                    return dates
                }
            }

            // Advance by N weeks.
            guard let nextStart = calendar.date(byAdding: .weekOfYear, value: interval, to: weekStart) else { break }
            weekStart = nextStart

            // Early exits for open-ended schedules.
            if let until = untilExclusive, weekStart >= until { break }
            if rule.count == nil, weekStart >= rangeUTC.upperBound { break }
        }

        return dates
    }

    /// Generates all occurrence instants for a monthly recurring event (BYMONTHDAY).
    /// Applies timezone-correct math in the event’s zone, preserves seconds/nanoseconds,
    /// treats `until` as day-inclusive, and counts all occurrences (not just those in `rangeUTC`).
    /// Invalid month-days for a given month are skipped (e.g., day 31 in February).
    ///
    /// - Parameters:
    ///   - startUTC: The first occurrence instant (stored in UTC).
    ///   - rule: Recurrence rule; `byMonthday` uses 1...31 (Apple semantics).
    ///   - rangeUTC: Return only occurrences within this absolute window (UTC instants).
    ///   - baseCalendar: Base calendar (e.g., `.gregorian`); its timeZone is overridden.
    ///   - eventTimeZone: The event’s local time zone where wall-clock rules apply.
    /// - Returns: Occurrence instants as `Date` values (absolute UTC instants).
    private static func generateMonthlyRecurrence(
        start startUTC: Date,
        rule: RecurrenceRule,
        within rangeUTC: Range<Date>,
        calendar baseCalendar: Calendar,
        eventTimeZone: TimeZone
    ) -> [Date] {
        // Work in the event's local zone so "day-of-month @ time" means local wall time.
        var calendar = baseCalendar
        calendar.timeZone = eventTimeZone

        var dates: [Date] = []
        let interval = max(1, rule.interval)

        // Preserve full wall-clock time (incl. seconds/nanoseconds).
        let timeComps = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: startUTC)

        // UNTIL: day-inclusive in the event zone → exclusive boundary at startOfDay(until)+1 day.
        let untilExclusive: Date? = rule.until.flatMap {
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0))
        }
        if let until = untilExclusive, startUTC >= until { return [] }

        // Month anchor (first day of the month of the start).
        let monthAnchor = calendar.dateInterval(of: .month, for: startUTC)?.start
            ?? calendar.startOfDay(for: startUTC)
        var monthStart = monthAnchor

        // Monthdays: default to start’s day; dedup/validate and sort.
        let defaultDay = calendar.component(.day, from: startUTC)
        var monthdays = (rule.byMonthday?.isEmpty == false ? rule.byMonthday! : [defaultDay])
            .filter { (1...31).contains($0) }
        monthdays = Array(Set(monthdays)).sorted()

        var occurrences = 0

        while true {
            // Year/Month components for this iteration.
            let ymComps = calendar.dateComponents([.year, .month], from: monthStart)

            // Valid day range for this month (e.g., 1...28/29/30/31).
            let validDayRange = calendar.range(of: .day, in: .month, for: monthStart)

            for day in monthdays {
                // Skip invalid days for this month.
                if let r = validDayRange, !r.contains(day) { continue }

                // Compose target local date components for this day with preserved time.
                var comps = ymComps
                comps.day = day
                comps.hour = timeComps.hour
                comps.minute = timeComps.minute
                comps.second = timeComps.second
                comps.nanosecond = timeComps.nanosecond

                // Try direct construction; if it fails (e.g., DST hole), fall back to nextDate().
                var candidate: Date? = calendar.date(from: comps)

                if candidate == nil {
                    // Start from the local start of that calendar day, then match intended time on that day.
                    var dayOnly = ymComps
                    dayOnly.day = day
                    if let dayStart = calendar.date(from: dayOnly) {
                        candidate = calendar.nextDate(
                            after: dayStart.addingTimeInterval(-1),
                            matching: comps,
                            matchingPolicy: .nextTimePreservingSmallerComponents,
                            repeatedTimePolicy: .first,
                            direction: .forward
                        )
                        // Ensure it didn’t roll out of the intended Y/M/D.
                        if let c = candidate {
                            let check = calendar.dateComponents([.year, .month, .day], from: c)
                            if check.year != ymComps.year || check.month != ymComps.month || check.day != day {
                                candidate = nil
                            }
                        }
                    }
                }

                guard let cand = candidate else { continue }

                // Respect series start.
                if cand < startUTC { continue }

                // Stop on UNTIL (exclusive).
                if let until = untilExclusive, cand >= until { return dates }

                // Count every valid occurrence (even if outside the requested return range).
                occurrences += 1

                // Add to output if within the requested window.
                if rangeUTC.contains(cand) {
                    if dates.last != cand { dates.append(cand) }
                }

                // Respect COUNT across all occurrences.
                if let count = rule.count, occurrences >= count {
                    return dates
                }
            }

            // Advance by N months (from the month anchor).
            guard let nextStart = calendar.date(byAdding: .month, value: interval, to: monthStart) else { break }
            monthStart = nextStart

            // Early exits for open-ended series.
            if let until = untilExclusive, monthStart >= until { break }
            if rule.count == nil, untilExclusive == nil, monthStart >= rangeUTC.upperBound { break }
        }

        return dates
    }
    
    /// Generates all occurrence instants for a yearly recurring event (BYMONTH + BYMONTHDAY).
    /// Timezone-correct (math in `eventTimeZone`), preserves seconds/nanoseconds,
    /// treats `until` as day-inclusive, and applies `count` across all occurrences.
    /// Invalid (month, day) combos are skipped (e.g., Feb 30).
    ///
    /// - Parameters:
    ///   - startUTC: The first occurrence instant (stored in UTC).
    ///   - rule: Recurrence rule; supports `byMonth` (1...12) and `byMonthday` (1...31).
    ///   - rangeUTC: Return only occurrences within this absolute window (UTC instants).
    ///   - baseCalendar: Base calendar (e.g. `.gregorian`); its timeZone is overridden.
    ///   - eventTimeZone: The event’s local time zone where wall-clock rules apply.
    /// - Returns: Occurrence instants as `Date` values (absolute UTC instants).
    private static func generateYearlyRecurrence(
        start startUTC: Date,
        rule: RecurrenceRule,
        within rangeUTC: Range<Date>,
        calendar baseCalendar: Calendar,
        eventTimeZone: TimeZone
    ) -> [Date] {
        // Work in the event's local zone so "month/day @ time" means local wall time.
        var calendar = baseCalendar
        calendar.timeZone = eventTimeZone

        var dates: [Date] = []
        let interval = max(1, rule.interval)

        // Preserve full wall-clock time.
        let timeComps = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: startUTC)

        // UNTIL: day-inclusive in event zone → exclusive boundary at startOfDay(until)+1 day.
        let untilExclusive: Date? = rule.until.flatMap {
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0))
        }
        if let until = untilExclusive, startUTC >= until { return [] }

        // Year anchor (start of the year containing start).
        let yearAnchor = calendar.dateInterval(of: .year, for: startUTC)?.start
            ?? calendar.startOfDay(for: startUTC)
        var yearStart = yearAnchor

        // BYMONTH default: start's month; dedup/validate/sort.
        let defaultMonth = calendar.component(.month, from: startUTC)
        var months = (rule.byMonth?.isEmpty == false ? rule.byMonth! : [defaultMonth])
            .filter { (1...12).contains($0) }
        months = Array(Set(months)).sorted()

        // BYMONTHDAY default: start's day; dedup/validate/sort.
        let defaultDay = calendar.component(.day, from: startUTC)
        var monthdays = (rule.byMonthday?.isEmpty == false ? rule.byMonthday! : [defaultDay])
            .filter { (1...31).contains($0) }
        monthdays = Array(Set(monthdays)).sorted()

        var occurrences = 0

        while true {
            let yComps = calendar.dateComponents([.year], from: yearStart)

            for month in months {
                // Build a month start to query valid day range.
                var ym = yComps
                ym.month = month
                guard let monthStart = calendar.date(from: ym) else { continue }
                let validDayRange = calendar.range(of: .day, in: .month, for: monthStart)

                for day in monthdays {
                    // Skip invalid days for this month (e.g., 31 in April).
                    if let r = validDayRange, !r.contains(day) { continue }

                    // Compose target local Y/M/D + preserved time.
                    var comps = ym
                    comps.day = day
                    comps.hour = timeComps.hour
                    comps.minute = timeComps.minute
                    comps.second = timeComps.second
                    comps.nanosecond = timeComps.nanosecond

                    // Try direct construction; if time is nonexistent (DST gap), fall back.
                    var candidate: Date? = calendar.date(from: comps)
                    if candidate == nil {
                        var dayOnly = ym
                        dayOnly.day = day
                        if let dayStart = calendar.date(from: dayOnly) {
                            candidate = calendar.nextDate(
                                after: dayStart.addingTimeInterval(-1),
                                matching: comps,
                                matchingPolicy: .nextTimePreservingSmallerComponents,
                                repeatedTimePolicy: .first,
                                direction: .forward
                            )
                            if let c = candidate {
                                let check = calendar.dateComponents([.year, .month, .day], from: c)
                                if check.year != yComps.year || check.month != month || check.day != day {
                                    candidate = nil
                                }
                            }
                        }
                    }

                    guard let cand = candidate else { continue }
                    if cand < startUTC { continue }
                    if let until = untilExclusive, cand >= until { return dates }

                    // Count every valid occurrence (even if outside returned range).
                    occurrences += 1

                    // Add to output if within the requested window.
                    if rangeUTC.contains(cand) {
                        if dates.last != cand { dates.append(cand) }
                    }

                    if let count = rule.count, occurrences >= count {
                        return dates
                    }
                }
            }

            // Advance by N years.
            guard let nextYear = calendar.date(byAdding: .year, value: interval, to: yearStart) else { break }
            yearStart = nextYear

            // Early exits for open-ended series.
            if let until = untilExclusive, yearStart >= until { break }
            if rule.count == nil, untilExclusive == nil, yearStart >= rangeUTC.upperBound { break }
        }

        return dates
    }

    static func addTodayIfNeeded(occurrences: [EventOccurrence], range: Range<Date>) -> [EventOccurrence] {
        let today = Date().startOfDay()
        var hasToday = false
        
        if !range.contains(today) {
            return occurrences
        }
        
        for occ in occurrences where occ.startDate.isSameDay(as: today) {
            hasToday = true
        }
        
        if !hasToday {
            var occ = occurrences
            occ.append(EventOccurrence(
                id: UUID(),
                userId: UUID(),
                eventId: UUID(),
                title: String(localized: "Nothing for today"),
                notes: nil,
                startDate: today,
                endDate: nil,
                isRecurring: false,
                location: nil,
                color: EventColor.yellow,
                reminderTriggers: nil,
                isOverride: false,
                isCancelled: false,
                updatedAt: today,
                createdAt: today,
                overrides: [],
                recurrence_rules: [],
                deletedAt: nil,
                needsSync: false,
                isFakeOccForEmptyToday: true,
                version: nil
            ))
            return occ
        }
        
        return occurrences
    }
}
