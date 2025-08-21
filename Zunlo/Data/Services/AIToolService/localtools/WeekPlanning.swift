//
//  WeekPlanning.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/19/25.
//

import Foundation

public struct Constraints {
    var workHours: [Int: (start: DateComponents, end: DateComponents)]? // weekday: 1..7
    var minFocusMins: Int = 30
    var maxFocusMins: Int = 120
}

protocol WeekPlanning {
    func proposePlan(start: Date, horizonDays: Int, timezone: TimeZone, objectives: [String], constraints: Constraints?) async throws -> ProposedPlan
}
