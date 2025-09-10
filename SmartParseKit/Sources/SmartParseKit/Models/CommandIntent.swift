//
//  UserIntent.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

public enum CommandIntent: String {
    case createTask         = "create_task"
    case createEvent        = "create_event"
    case rescheduleTask     = "reschedule_task"
    case rescheduleEvent    = "reschedule_event"
    case updateTask         = "update_task"
    case updateEvent        = "update_event"
    case planWeek           = "plan_week"
    case planDay            = "plan_day"
    case showAgenda         = "show_agenda"
    case moreInfo           = "more_info"
    case unknown
}
