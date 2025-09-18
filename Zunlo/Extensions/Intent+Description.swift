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
        case .createTask: return "Create task".localized
        case .createEvent: return "Create event".localized
        case .updateTask: return "Update task".localized
        case .updateEvent: return "Update event".localized
        case .rescheduleTask: return "Reschedule task".localized
        case .rescheduleEvent: return "Reschedule event".localized
        case .cancelTask: return "Cancel task".localized
        case .cancelEvent: return "Cancel event".localized
        case .view: return "View".localized
        case .plan: return "Plan".localized
        case .unknown:  return "Process request".localized
        }
    }
}
