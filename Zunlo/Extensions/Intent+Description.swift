//
//  Intent+Description.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/18/25.
//

import SmartParseKit

extension Intent {
    var localizedDescription: String {
        switch self {
        case .createTask: return String(localized: "Create task")
        case .createEvent: return String(localized: "Create event")
        case .updateTask: return String(localized: "Update task")
        case .updateEvent: return String(localized: "Update event")
        case .rescheduleTask: return String(localized: "Reschedule task")
        case .rescheduleEvent: return String(localized: "Reschedule event")
        case .cancelTask: return String(localized: "Cancel task")
        case .cancelEvent: return String(localized: "Cancel event")
        case .view: return String(localized: "View")
        case .plan: return String(localized: "Plan")
        case .unknown:  return String(localized: "Process request")
        }
    }
}
