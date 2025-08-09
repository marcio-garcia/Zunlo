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
    public let calendar: Calendar = Calendar.current
}

public protocol WeatherProvider {
    func summaryForToday() async -> (summary: String?, precipNext4h: Double?, rainingSoon: Bool)
}

protocol TaskRepo {
    func overdueCount(on date: Date) async -> Int
    func dueTodayCount(on date: Date) async -> Int
    func highPriorityCount(on date: Date) async -> Int
    func topUnscheduled(limit: Int) async -> [UserTask]
    func typicalStartTimeComponents() async -> DateComponents?
}

public protocol EventRepo {
    func freeWindows(on date: Date, minimumMinutes: Int) async -> [TimeWindow]
    func nextEventStart(after: Date, on date: Date) async -> Date?
    func conflictingItemsCount(on date: Date) async -> Int
}
