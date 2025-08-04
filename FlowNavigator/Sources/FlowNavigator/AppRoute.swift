//
//  AppRoute.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/4/25.
//

import Foundation

public enum SheetRoute: Identifiable, Equatable {
    case settings
    case addTask
    case editTask(_ id: UUID)
    case addEvent
    case editEvent(_ id: UUID)
    
    
    public var id: String {
        switch self {
        case .settings: return "settings"
        case .addTask: return "addTask"
        case .editTask(let id): return "editTask_\(id)"
        case .addEvent: return "addEvent"
        case .editEvent(let id): return "editEvent_\(id)"
        }
    }
}

public enum FullScreenRoute: Identifiable, Equatable {
    case onboarding
    case login
    case eventCalendar
    case taskInbox

    public var id: String {
        switch self {
        case .onboarding: return "onboarding"
        case .login: return "login"
        case .eventCalendar: return "eventCalendar"
        case .taskInbox: return "taskInbox"
        }
    }
}

public enum DialogRoute: Identifiable, Equatable {
    case deleteTask(id: UUID)
    case deleteEvent(id: UUID)
    case editRecurringEvent

    public var id: String {
        switch self {
        case .deleteTask(let id): return "deleteTask_\(id)"
        case .deleteEvent(let id): return "deleteEvent_\(id)"
        case .editRecurringEvent: return "editRecurringEvent"
        }
    }
}

public enum StackRoute: Hashable {
    case taskDetail(_ id: UUID)
}
