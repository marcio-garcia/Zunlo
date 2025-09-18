//
//  CommandIntent.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/17/25.
//

public enum Intent: String {
    case createTask         = "create_task"
    case createEvent        = "create_event"
    case rescheduleTask     = "reschedule_task"
    case rescheduleEvent    = "reschedule_event"
    case updateTask         = "update_task"
    case updateEvent        = "update_event"
    case cancelTask         = "cancel_task"
    case cancelEvent        = "cancel_event"
    case view               = "view"
    case plan               = "plan"
    case unknown
}
