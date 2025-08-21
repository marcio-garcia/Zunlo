//
//  NavigationViewFactory.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/4/25.
//

import SwiftUI

struct NavigationViewFactory {
    
    let task: TaskViews?
    let event: EventViews?
    let settings: SettingsViews?
    let chat: ChatViews?
    
//    var buildOnboardingView: (() -> AnyView)?
//    var buildLoginView: (() -> AnyView)?
//    
//    var buildSettingsView: (() -> AnyView)?
//    
//    var buildTaskInboxView: (() -> AnyView)?
//    var buildAddTaskView: (() -> AnyView)?
//    var buildEditTaskView: ((_ id: UUID) -> AnyView)?
//    var buildTaskDetailView: ((_ id: UUID) -> AnyView)?
//    var buildDeleteTaskConfirmationView: ((_ id: UUID) -> AnyView)?
//    
//    var buildEventCalendarView: (() -> AnyView)?
//    var buildAddEventView: (() -> AnyView)?
//    var buildEditEventView: ((_ id: UUID) -> AnyView)?
//    var buildEventDetailView: ((_ id: UUID) -> AnyView)?
//    var buildDeleteEventConfirmationView: ((_ id: UUID) -> AnyView)?
//    var buildEditRecurringView: (() -> AnyView)?
    
    init(
        task: TaskViews? = nil,
        event: EventViews? = nil,
        settings: SettingsViews? = nil,
        chat: ChatViews? = nil
//        buildOnboardingView: (() -> AnyView)? = nil,
//        buildLoginView: (() -> AnyView)? = nil,
//        buildSettingsView: (() -> AnyView)? = nil,
//        buildTaskInboxView: (() -> AnyView)? = nil,
//        buildAddTaskView: (() -> AnyView)? = nil,
//        buildEditTaskView: ((_ id: UUID) -> AnyView)? = nil,
//        buildTaskDetailView: ((_ id: UUID) -> AnyView)? = nil,
//        buildDeleteTaskConfirmationView: ((_ id: UUID) -> AnyView)? = nil,
//        buildEventCalendarView: (() -> AnyView)? = nil,
//        buildAddEventView: (() -> AnyView)? = nil,
//        buildEditEventView: ((_ id: UUID) -> AnyView)? = nil,
//        buildEventDetailView: ((_ id: UUID) -> AnyView)? = nil,
//        buildDeleteEventConfirmationView: ((_ id: UUID) -> AnyView)? = nil,
//        buildEditRecurringView: (() -> AnyView)? = nil
    ) {
        self.task = task
        self.event = event
        self.settings = settings
        self.chat = chat
//        self.buildOnboardingView = buildOnboardingView
//        self.buildLoginView = buildLoginView
//        self.buildSettingsView = buildSettingsView
//        self.buildTaskInboxView = buildTaskInboxView
//        self.buildAddTaskView = buildAddTaskView
//        self.buildEditTaskView = buildEditTaskView
//        self.buildTaskDetailView = buildTaskDetailView
//        self.buildDeleteTaskConfirmationView = buildDeleteTaskConfirmationView
//        self.buildEventCalendarView = buildEventCalendarView
//        self.buildAddEventView = buildAddEventView
//        self.buildEditEventView = buildEditEventView
//        self.buildEventDetailView = buildEventDetailView
//        self.buildDeleteEventConfirmationView = buildDeleteEventConfirmationView
//        self.buildEditRecurringView = buildEditRecurringView
    }
}
