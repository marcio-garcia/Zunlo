//
//  AIContextBuilder.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

public enum AIContextBuilder {
    static func build(
        time: TimeProvider,
        tasks: TaskSuggestionEngine,
        events: EventSuggestionEngine,
        weather: WeatherProvider?
    ) async -> AIContext {
        let now = time.now
        let cal = time.calendar
        let dayStart = cal.startOfDay(for: now)
        let dayEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: dayStart)!

        let policy = SuggestionPolicy.defaultForApp()
        
        async let overdue = tasks.overdueCount(on: now)
        async let dueToday = tasks.dueTodayCount(on: now)
        async let highPrio = tasks.highPriorityCount(on: now)
        async let topUnscheduled = tasks.topUnscheduled(limit: 5)
        async let windows = events.freeWindows(on: now, minimumMinutes: 30, policy: policy)
        async let nextStart = events.nextEventStart(after: now, on: now)
        async let conflicts = events.conflictingItemsCount(on: now, policy: policy)
        async let typicalStart = tasks.typicalStartTimeComponents()

        var weatherSummary: String? = nil
        var precip: Double? = nil
        var rainingSoon = false
        if let weather {
            let w = await weather.summaryForToday()
            weatherSummary = w.summary
            precip = w.precipNext4h
            rainingSoon = w.rainingSoon
        }

        let free = await windows
        let longest = free.max(by: { $0.duration < $1.duration })

        return AIContext(
            now: now,
            dayStart: dayStart,
            dayEnd: dayEnd,
            period: period(for: now, calendar: cal),
            nextEventStart: await nextStart,
            freeWindows: free,
            longestFreeWindow: longest,
            overdueCount: await overdue,
            dueTodayCount: await dueToday,
            highPriorityCount: await highPrio,
            topUnscheduledTasks: await topUnscheduled,
            typicalStartTime: await typicalStart,
            weatherSummary: weatherSummary,
            precipitationChanceNext4h: precip,
            isRainingSoon: rainingSoon,
            conflictingItemsCount: await conflicts
        )
    }

    private static func period(for date: Date, calendar: Calendar) -> DayPeriod {
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
