//
//  Providers.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation
import CoreLocation

public protocol TimeProvider {
    var now: Date { get }
    var calendar: Calendar { get }
}

public struct SystemTimeProvider: TimeProvider {
    public let now: Date = Date()
    public let calendar: Calendar = Calendar.appDefault
}

public protocol WeatherProvider {
    func summaryForToday() async -> (summary: String?, precipNext4h: Double?, rainingSoon: Bool)
}

protocol TaskSuggestionEngine {
    func overdueCount(on date: Date) async -> Int
    func dueTodayCount(on date: Date) async -> Int
    func highPriorityCount(on date: Date) async -> Int
    func topUnscheduled(limit: Int) async -> [UserTask]
    func typicalStartTimeComponents() async -> DateComponents?
}

public protocol EventSuggestionEngine {
    func freeWindows(on date: Date, minimumMinutes: Int, policy: SuggestionPolicy) async -> [TimeWindow]
    func nextEventStart(after: Date, on date: Date, policy: SuggestionPolicy) async -> Date?
    func conflictingItemsCount(on date: Date, policy: SuggestionPolicy) async -> Int
}
