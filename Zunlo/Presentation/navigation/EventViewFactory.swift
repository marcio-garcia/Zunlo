//
//  EventViewFactory.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/7/25.
//

import SwiftUI
import FlowNavigator

enum EditEventDialogOption: String {
    case single
    case all
    case future
    case cancel
}

struct EventViewFactory: EventViews {
    let viewID: UUID
    let nav: AppNav
    let onAddEditEventDismiss: (() -> Void)?
    
    internal init(viewID: UUID, nav: AppNav, onAddEditEventDismiss: (() -> Void)? = nil) {
        self.viewID = viewID
        self.nav = nav
        self.onAddEditEventDismiss = onAddEditEventDismiss
    }
    
    func buildEventCalendarView() -> AnyView {
        AnyView(
            CalendarScheduleContainer(
                viewModel: CalendarScheduleViewModel(
                    eventFetcher: EventFetcher(repo: AppState.shared.eventRepository!),
                    locationService: AppState.shared.locationService!
                ), onTapClose: {
                    Task { await MainActor.run { nav.pop() } }
                }
            )
            .toolbar(.hidden, for: .navigationBar)
            .swipeToPop {
                Task { await MainActor.run { nav.pop() } }
            }
            .ignoresSafeArea()
            .environmentObject(nav)
        )
    }

    func buildAddEventView() -> AnyView {
        AnyView(
            AddEditEventView(
                viewModel: AddEditEventViewModel(mode: .add, editor: EventEditor(repo: AppState.shared.eventRepository!)),
                onDismiss: { date in
                    onAddEditEventDismiss?()
                }
            )
            .environmentObject(nav)
        )
    }

    func buildEditEventView(editMode: AddEditEventViewMode) -> AnyView {
        AnyView(
            AddEditEventView(
                viewModel: AddEditEventViewModel(mode: editMode, editor: EventEditor(repo: AppState.shared.eventRepository!)),
                onDismiss: { date in
                    onAddEditEventDismiss?()
                }
            )
            .environmentObject(nav)
        )
    }

    func buildEventDetailView(id: UUID) -> AnyView {
        AnyView(Text("Event detail view for \(id)")) // Replace with actual view
    }

    func buildDeleteEventConfirmationView(mode: AddEditEventViewMode, onOptionSelected: @escaping (String) -> Void) -> AnyView {
        var title: String = ""
        
        switch mode {
        case .add:
            break
        case let .editAll(event: _, recurrenceRule: rule):
            if rule == nil {
                title = String(localized: "Delete event")
            } else {
                title = String(localized: "Delete all series")
            }
            
        case .editSingle:
            title = String(localized: "Delete this event")
        case .editOverride:
            title = String(localized: "Delete this event")
        case .editFuture:
            title = String(localized: "Delete this and future events")
        }
        return AnyView(
            Group {
                Button(title, role: .destructive) {
                    onOptionSelected("delete")
                }
                Button("Cancel", role: .cancel) {
                    onOptionSelected("cancel")
                }
            }
        )
    }

    func buildEditRecurringEventView(onOptionSelected: @escaping (String) -> Void) -> AnyView {
        AnyView(
            Group {
                Button("Edit only this occurrence") {
                    onOptionSelected(EditEventDialogOption.single.rawValue)
                }
                Button("Edit this and future occurrences") {
                    onOptionSelected(EditEventDialogOption.future.rawValue)
                }
                Button("Edit all occurrences") {
                    onOptionSelected(EditEventDialogOption.all.rawValue)
                }
                Button("Cancel", role: .cancel) {
                    onOptionSelected(EditEventDialogOption.cancel.rawValue)
                }
            }
        )
    }
}
