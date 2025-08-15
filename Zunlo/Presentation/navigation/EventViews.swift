//
//  EventViews.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/7/25.
//

import SwiftUI

protocol EventViews {
    func buildEventCalendarView() -> AnyView
    func buildAddEventView() -> AnyView
    func buildEditEventView(editMode: AddEditEventViewMode) -> AnyView
    func buildEventDetailView(id: UUID) -> AnyView
    func buildDeleteEventConfirmationView(mode: AddEditEventViewMode, onOptionSelected: @escaping (String) -> Void) -> AnyView
    func buildEditRecurringEventView(onOptionSelected: @escaping (String) -> Void) -> AnyView
}
