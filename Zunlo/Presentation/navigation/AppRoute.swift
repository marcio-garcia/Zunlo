//
//  AppRoute.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/4/25.
//

import Foundation
import FlowNavigator

enum SheetRoute: AppSheetRoute {
    case settings
    case addTask
    case editTask(_ id: UUID)
    case addEvent
    case editEvent(_ editMode: AddEditEventViewMode)
    
    var id: String {
        switch self {
        case .settings: return "settings"
        case .addTask: return "addTask"
        case .editTask(let id): return "editTask_\(id)"
        case .addEvent: return "addEvent"
        case .editEvent(let id): return "editEvent_\(id)"
        }
    }
}

enum FullScreenRoute: AppFullScreenRoute {
    case onboarding
    case login

    var id: String {
        switch self {
        case .onboarding: return "onboarding"
        case .login: return "login"
        }
    }
}

enum DialogRoute: AppDialogRoute {
    case deleteTask
    case deleteEvent(id: UUID)
    case editRecurringEvent

    var id: String {
        switch self {
        case .deleteTask: return "deleteTask"
        case .deleteEvent(let id): return "deleteEvent_\(id)"
        case .editRecurringEvent: return "editRecurringEvent"
        }
    }
}

enum StackRoute: AppStackRoute {
    case eventCalendar
    case taskDetail(_ id: UUID)
    case taskInbox
}
