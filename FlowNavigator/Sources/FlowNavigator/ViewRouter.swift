//
//  ViewRouter.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/4/25.
//

import SwiftUI

@MainActor
public struct ViewRouter {
    
    // MARK: - Sheet Views
    static public func sheetView(for route: SheetRoute, navigationManager: AppNavigationManager, builders: ViewBuilders) -> some View {
        switch route {
        case .addTask: return checkBuilder(builders.buildAddTaskView, navigationManager: navigationManager)
        case .editTask(let id): return checkBuilder(builders.buildEditTaskView, id: id, navigationManager: navigationManager)
        case .settings: return checkBuilder(builders.buildSettingsView, navigationManager: navigationManager)
        case .addEvent: return checkBuilder(builders.buildAddEventView, navigationManager: navigationManager)
        case .editEvent(let id): return checkBuilder(builders.buildEditEventView, id: id, navigationManager: navigationManager)
        case .taskInbox: return checkBuilder(builders.buildTaskInboxView, navigationManager: navigationManager)
        }
    }

    // MARK: - Full-Screen Views
    static public func fullScreenView(for route: FullScreenRoute, navigationManager: AppNavigationManager, builders: ViewBuilders) -> some View {
        switch route {
        case .onboarding: return checkBuilder(builders.buildOnboardingView, navigationManager: navigationManager)
        case .login: return checkBuilder(builders.buildLoginView, navigationManager: navigationManager)
        case .eventCalendar: return checkBuilder(builders.buildEventCalendarView, navigationManager: navigationManager)
        case .taskInbox: return checkBuilder(builders.buildTaskInboxView, navigationManager: navigationManager)
        }
    }

    // MARK: - Confirmation Dialog Buttons
    static public func dialogButtons(for route: DialogRoute, navigationManager: AppNavigationManager, builders: ViewBuilders) -> some View {
        switch route {
        case .deleteTask(let id): return checkBuilder(builders.buildDeleteTaskConfirmationView, id: id, navigationManager: navigationManager)
        case .deleteEvent(let id): return checkBuilder(builders.buildDeleteEventConfirmationView, id: id, navigationManager: navigationManager)
        case .editRecurringEvent: return checkBuilder(builders.buildEditRecurringView, navigationManager: navigationManager)
        }
    }

    // MARK: - NavigationStack Destinations
    static public func navigationDestination(for route: StackRoute, navigationManager: AppNavigationManager, builders: ViewBuilders) -> some View {
        switch route {
        case .eventCalendar: return checkBuilder(builders.buildEventCalendarView, navigationManager: navigationManager)
        case .taskDetail(let id): return checkBuilder(builders.buildTaskDetailView, id: id, navigationManager: navigationManager)
        case .taskInbox: return checkBuilder(builders.buildTaskInboxView, navigationManager: navigationManager)
        }
    }
    
    private static func checkBuilder(
        _ builder: (() -> AnyView)?,
        navigationManager: AppNavigationManager
    ) -> AnyView {
        guard let view = builder?() else {
            return AnyView(FallbackView(message: "No view found for this route.", nav: navigationManager, viewID: UUID()))
        }
        return AnyView(view)
    }
    
    private static func checkBuilder(
        _ builder: ((UUID) -> AnyView)?,
        id: UUID,
        navigationManager: AppNavigationManager
    ) -> AnyView {
        guard let view = builder?(id) else {
            return AnyView(FallbackView(message: "No view found for this route.", nav: navigationManager, viewID: UUID()))
        }
        return AnyView(view)
    }
}
