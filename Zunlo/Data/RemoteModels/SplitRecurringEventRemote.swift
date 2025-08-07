//
//  SplitRecurringEventRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/6/25.
//

import Foundation

struct SplitRecurringEventRemote: Codable {
    let originalEventId: UUID
    let splitFromDate: Date
    let newEventData: NewEventData

    enum CodingKeys: String, CodingKey {
        case originalEventId = "original_event_id"
        case splitFromDate = "split_from_date"
        case newEventData = "new_event_data"
    }

    struct NewEventData: Codable {
        let userId: UUID
        let title: String
        let description: String?
        let startDatetime: Date
        let endDatetime: Date?
        let isRecurring: Bool
        let location: String?
        let color: EventColor?
        let reminderTriggers: [ReminderTrigger]?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case title
            case description
            case startDatetime = "start_datetime"
            case endDatetime = "end_datetime"
            case isRecurring = "is_recurring"
            case location
            case color
            case reminderTriggers = "reminder_triggers"
        }
    }
}

struct SplitRecurringEventResponse: Codable {
    let success: Bool
    let newEventId: UUID

    enum CodingKeys: String, CodingKey {
        case success
        case newEventId = "new_event_id"
    }
}
