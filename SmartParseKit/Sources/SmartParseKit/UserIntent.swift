//
//  UserIntent.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

public enum UserIntent: String {
    case createTask = "create_task"
    case createEvent = "create_event"
    case updateReschedule = "update_reschedule"
    case planWeek = "plan_week"
    case planDay = "plan_day"
    case showAgenda = "show_agenda"
    case unknown
}
