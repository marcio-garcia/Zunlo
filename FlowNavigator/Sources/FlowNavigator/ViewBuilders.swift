//
//  ViewBuilders.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/4/25.
//

import SwiftUI

public struct ViewBuilders {
    
    public var buildOnboardingView: (() -> AnyView)?
    public var buildLoginView: (() -> AnyView)?
    
    public var buildSettingsView: (() -> AnyView)?
    
    public var buildTaskInboxView: (() -> AnyView)?
    public var buildAddTaskView: (() -> AnyView)?
    public var buildEditTaskView: ((_ id: UUID) -> AnyView)?
    public var buildTaskDetailView: ((_ id: UUID) -> AnyView)?
    public var buildDeleteTaskConfirmationView: ((_ id: UUID) -> AnyView)?
    
    public var buildEventCalendarView: (() -> AnyView)?
    public var buildAddEventView: (() -> AnyView)?
    public var buildEditEventView: ((_ id: UUID) -> AnyView)?
    public var buildEventDetailView: ((_ id: UUID) -> AnyView)?
    public var buildDeleteEventConfirmationView: ((_ id: UUID) -> AnyView)?
    
    public init(
        buildOnboardingView: (() -> AnyView)? = nil,
        buildLoginView: (() -> AnyView)? = nil,
        buildSettingsView: (() -> AnyView)? = nil,
        buildTaskInboxView: (() -> AnyView)? = nil,
        buildAddTaskView: (() -> AnyView)? = nil,
        buildEditTaskView: ((_ id: UUID) -> AnyView)? = nil,
        buildTaskDetailView: ((_ id: UUID) -> AnyView)? = nil,
        buildDeleteTaskConfirmationView: ((_ id: UUID) -> AnyView)? = nil,
        buildEventCalendarView: (() -> AnyView)? = nil,
        buildAddEventView: (() -> AnyView)? = nil,
        buildEditEventView: ((_ id: UUID) -> AnyView)? = nil,
        buildEventDetailView: ((_ id: UUID) -> AnyView)? = nil,
        buildDeleteEventConfirmationView: ((_ id: UUID) -> AnyView)? = nil
    ) {
        self.buildOnboardingView = buildOnboardingView
        self.buildLoginView = buildLoginView
        self.buildSettingsView = buildSettingsView
        self.buildAddTaskView = buildAddTaskView
        self.buildEditTaskView = buildEditTaskView
        self.buildTaskDetailView = buildTaskDetailView
        self.buildDeleteTaskConfirmationView = buildDeleteTaskConfirmationView
        self.buildEventCalendarView = buildEventCalendarView
        self.buildAddEventView = buildAddEventView
        self.buildEditEventView = buildEditEventView
        self.buildEventDetailView = buildEventDetailView
        self.buildDeleteEventConfirmationView = buildDeleteEventConfirmationView
    }
}
