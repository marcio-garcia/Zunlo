//
//  EventFilter.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/16/25.
//

import Foundation

struct EventFilter {
    var userId: UUID?
    var startDateRange: ClosedRange<Date>?
    var endDateRange: ClosedRange<Date>?
    
    init(
        userId: UUID? = nil,
        startDateRange: ClosedRange<Date>? = nil,
        endDateRange: ClosedRange<Date>? = nil
    ) {
        self.userId = userId
        self.startDateRange = startDateRange
        self.endDateRange = endDateRange
    }
}
