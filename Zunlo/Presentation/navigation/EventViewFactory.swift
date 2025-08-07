//
//  EventViewFactory.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/7/25.
//

import SwiftUI
import FlowNavigator

enum EditEventDialogOption {
    case single
    case all
    case future
    case cancel
}

struct EventViewFactory: EventViews {
    let viewID: UUID
    let nav: AppNav
    let locationService: LocationService
    let repository: EventRepository
    var onEditDialogSelection: ((EditEventDialogOption) -> Void)?

    func buildEventCalendarView() -> AnyView {
        AnyView(
            CalendarScheduleContainer(
                viewModel: CalendarScheduleViewModel(
                    repository: repository,
                    locationService: locationService
                ), onTapClose: {
                    Task { await MainActor.run { nav.pop() } }
                }
            )
            .toolbar(.hidden, for: .navigationBar)
            .ignoresSafeArea()
        )
    }

    func buildAddEventView() -> AnyView {
        AnyView(
            AddEditEventView(
                viewModel: AddEditEventViewModel(mode: .add, repository: repository)
            )
        )
    }

    func buildEditEventView(editMode: AddEditEventViewMode) -> AnyView {
        AnyView(
            AddEditEventView(
                viewModel: AddEditEventViewModel(mode: editMode, repository: repository)
            )
        )
    }

    func buildEventDetailView(id: UUID) -> AnyView {
        AnyView(Text("Event detail view for \(id)")) // Replace with actual view
    }

    func buildDeleteEventConfirmationView(id: UUID) -> AnyView {
        AnyView(
            Group {
                Button("Delete this event", role: .destructive) {
                    nav.dismissDialog(for: viewID)
                    nav.dismissSheet(for: viewID)
                }
                Button("Cancel", role: .cancel) {
                    nav.dismissDialog(for: viewID)
                }
            }
        )
    }

    func buildEditRecurringEventView() -> AnyView {
        AnyView(
            Group {
                Button("Edit only this occurrence") {
                    onEditDialogSelection?(.single)
                }
                Button("Edit this and future occurrences") {
                    onEditDialogSelection?(.future)
                }
                Button("Edit all occurrences") {
                    onEditDialogSelection?(.all)
                }
                Button("Cancel", role: .cancel) {
                    onEditDialogSelection?(.cancel)
                }
            }
        )
    }
}

