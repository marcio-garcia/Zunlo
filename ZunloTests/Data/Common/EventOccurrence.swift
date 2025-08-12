//
//  Event.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

import Foundation
@testable import Zunlo

extension EventOccurrence {
    init(startDate: Date, endDate: Date?) {
        self.init(
            id: UUID(),
            userId: UUID(),
            eventId: UUID(),
            title: "Test Event",
            description: "Test description",
            startDate: startDate,
            endDate: endDate,
            isRecurring: false,
            location: nil,
            color: .yellow,
            reminderTriggers: nil,
            isOverride: false,
            isCancelled: false,
            updatedAt: Date(),
            createdAt: Date(),
            overrides: [],
            recurrence_rules: [],
            isFakeOccForEmptyToday: false
        )
    }
}
