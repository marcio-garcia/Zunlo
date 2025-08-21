//
//  ViewRouter.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/4/25.
//

import SwiftUI
import FlowNavigator

@MainActor
struct ViewRouter {
    
    // MARK: - Sheet Views
    static func sheetView(for route: SheetRoute, navigationManager: AppNav, factory: NavigationViewFactory) -> some View {
        switch route {
        case .addTask, .editTask:
            return AnyView(TaskViewRouter.sheetView(for: route, navigationManager: navigationManager, factory: factory.task!))
        case .addEvent, .editEvent:
            return AnyView(EventViewRouter.sheetView(for: route, navigationManager: navigationManager, factory: factory.event!))
        case .settings:
            return AnyView(SettingsViewRouter.sheetView(for: route, nav: navigationManager, factory: factory.settings!))
        }
    }

    // MARK: - Full-Screen Views
    static func fullScreenView(for route: FullScreenRoute, navigationManager: AppNav, factory: NavigationViewFactory) -> some View {
        FallbackView.fallback("Not implemented.", nav: navigationManager, viewID: UUID())
    }

    // MARK: - Confirmation Dialog Buttons
    static func dialogView(
        for route: DialogRoute,
        navigationManager: AppNav,
        factory: NavigationViewFactory,
        onOptionSelected: @escaping (String) -> Void
    ) -> some View {
        switch route {
        case .deleteTask:
            return AnyView(TaskViewRouter.dialogView(for: route, navigationManager: navigationManager, factory: factory.task!, onOptionSelected: onOptionSelected))
        case .deleteEvent, .editRecurringEvent:
            return AnyView(EventViewRouter.dialogView(for: route, navigationManager: navigationManager, factory: factory.event!, onOptionSelected: onOptionSelected))
        case .deleteChatMessage(let id):
            return AnyView(ChatViewRouter.dialogView(for: route, navigationManager: navigationManager, factory: factory.chat!))
        case .deleteAllChat:
            return AnyView(ChatViewRouter.dialogView(for: route, navigationManager: navigationManager, factory: factory.chat!))
        }
    }

    // MARK: - NavigationStack Destinations
    static func navigationDestination(for route: StackRoute, navigationManager: AppNav, factory: NavigationViewFactory) -> some View {
        switch route {
        case .eventCalendar:
            return AnyView(EventViewRouter.navigationDestination(for: route, navigationManager: navigationManager, factory: factory.event!))
        case .taskInbox, .taskDetail:
            return AnyView(TaskViewRouter.navigationDestination(for: route, navigationManager: navigationManager, factory: factory.task!))

        }
    }
}
