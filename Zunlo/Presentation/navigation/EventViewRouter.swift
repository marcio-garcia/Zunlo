//
//  EventViewRouter.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/7/25.
//

import SwiftUI
import FlowNavigator

enum EventViewRouter {
    static func sheetView(for route: SheetRoute, navigationManager nav: AppNav, factory: EventViews) -> some View {
        switch route {
        case .addEvent:
            return factory.buildAddEventView()
        case .editEvent(let editMode):
            return factory.buildEditEventView(editMode: editMode)
        default:
            return AnyView(FallbackView(message: "Unknown event sheet", nav: nav, viewID: UUID()))
        }
    }

    static func dialogView(
        for route: DialogRoute,
        navigationManager nav: AppNav,
        factory: EventViews,
        onOptionSelected: @escaping (String) -> Void
    ) -> some View {
        switch route {
        case .deleteEvent(let mode):
            return factory.buildDeleteEventConfirmationView(mode: mode, onOptionSelected: onOptionSelected)
        case .editRecurringEvent:
            return factory.buildEditRecurringEventView(onOptionSelected: onOptionSelected)
        default:
            return AnyView(FallbackView(message: "Unknown event dialog", nav: nav, viewID: UUID()))
        }
    }

    static func navigationDestination(for route: StackRoute, navigationManager nav: AppNav, factory: EventViews) -> some View {
        switch route {
        case .eventCalendar:
            return factory.buildEventCalendarView()
        default:
            return AnyView(FallbackView(message: "Unknown event route", nav: nav, viewID: UUID()))
        }
    }
}
