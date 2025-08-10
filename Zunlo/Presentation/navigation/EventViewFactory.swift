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

    func buildDeleteEventConfirmationView(onOptionSelected: @escaping (String) -> Void) -> AnyView {
        AnyView(
            Group {
                Button("Delete this event", role: .destructive) {
                    onOptionSelected("delete")
//                    nav.dismissDialog(for: viewID)
//                    nav.dismissSheet(for: viewID)
                }
                Button("Cancel", role: .cancel) {
                    onOptionSelected("cancel")
//                    nav.dismissDialog(for: viewID)
                }
            }
        )
    }

    func buildEditRecurringEventView(onOptionSelected: @escaping (String) -> Void) -> AnyView {
        AnyView(
            Group {
                Button("Edit only this occurrence") {
                    onOptionSelected(EditEventDialogOption.single.rawValue)
//                    onEditDialogSelection?(.single)
                }
                Button("Edit this and future occurrences") {
                    onOptionSelected(EditEventDialogOption.future.rawValue)
//                    onEditDialogSelection?(.future)
                }
                Button("Edit all occurrences") {
                    onOptionSelected(EditEventDialogOption.all.rawValue)
//                    onEditDialogSelection?(.all)
                }
                Button("Cancel", role: .cancel) {
                    onOptionSelected(EditEventDialogOption.cancel.rawValue)
//                    onEditDialogSelection?(.cancel)
                }
            }
        )
    }
}
