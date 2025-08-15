//
//  DaySection.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

// MARK: - Grouped Sections (for day-based UI)

import Foundation

public struct DaySection: Identifiable, Hashable {
    public let id: String        // ISO8601 of start-of-day
    public let date: Date
    public var items: [ChatMessage]

    public init(id: String, date: Date, items: [ChatMessage]) {
        self.id = id
        self.date = date
        self.items = items
    }
}
