//
//  DaySection.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

// MARK: - Grouped Sections (for day-based UI)

import Foundation

struct DaySection: Identifiable, Hashable {
    let id: String        // ISO8601 of start-of-day
    let date: Date
    var items: [ChatMessage]

    init(id: String, date: Date, items: [ChatMessage]) {
        self.id = id
        self.date = date
        self.items = items
    }
}
