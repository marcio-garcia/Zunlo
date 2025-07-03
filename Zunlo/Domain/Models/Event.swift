//
//  Event.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/26/25.
//

import Foundation

struct Event: Identifiable, Sendable {
    let id: UUID?
    let userId: UUID?
    var title: String
    var createdAt: Date?
    var dueDate: Date
    var recurrence: RecurrenceRule
    var isComplete: Bool
    
    static var empty: Event {
        return Event(id: nil,
                     userId: nil,
                     title: "",
                     createdAt: nil,
                     dueDate: Date(),
                     recurrence: .none,
                     isComplete: false)
    }
}

extension Event {
    func occurs(on date: Date) -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: dueDate)
        let target = cal.startOfDay(for: date)

        guard target >= start else { return false }

        switch recurrence {
        case .none:
            return target == start
        case .daily:
            return target >= start
        case .weekly(let dayOfWeek):
            // Only true if weekday matches and target is after or same as start
            return cal.component(.weekday, from: target) == dayOfWeek
        case .monthly(let day):
            return cal.component(.day, from: target) == day
        }
    }
}
