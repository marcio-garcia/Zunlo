//
//  CommandIntent.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/17/25.
//

public enum Intent: String, CustomStringConvertible {
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
    
    public var description: String {
        switch self {
        case .createTask: return "Create task"
        case .createEvent: return "Create event"
        case .updateTask: return "Update task"
        case .updateEvent: return "Update event"
        case .rescheduleTask: return "Reschedule task"
        case .rescheduleEvent: return "Reschedule event"
        case .cancelTask: return "Cancel task"
        case .cancelEvent: return "Cancel event"
        case .view: return "View"
        case .plan: return "Plan"
        case .unknown:  return "Process request"
        }
    }
}
