//
//  EventEditHandler.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/2/25.
//

import SwiftUI

enum AddEditEventViewMode: Identifiable, Equatable {
    case add
    case editAll(event: EventOccurrence, recurrenceRule: RecurrenceRule?)
    case editSingle(parentEvent: EventOccurrence, recurrenceRule: RecurrenceRule?, occurrence: EventOccurrence)
    case editOverride(override: EventOverride)
    case editFuture(parentEvent: EventOccurrence, recurrenceRule: RecurrenceRule?, startingFrom: EventOccurrence)

    
    var id: String {
        switch self {
        case .add:
            return "add"
            
        case .editAll(let event, _):
            return "editAll-\(event.id)"
            
        case .editSingle(let parent, _, let occurrence):
            return "editSingle-\(parent.id)-\(occurrence.startDate.timeIntervalSince1970)"
            
        case .editOverride(let override):
            return "editOverride-\(override.id ?? UUID())"
            
        case .editFuture(let parent, _, let from):
            return "editFuture-\(parent.id)-\(from.startDate.timeIntervalSince1970)"
        }
    }
}

final class EventEditHandler: ObservableObject {
    @Published var editMode: AddEditEventViewMode?
    @Published var showEditChoiceDialog = false
    var editChoiceContext: EditChoiceContext?

    var allRecurringParentOccurrences: [EventOccurrence] = []

    func handleEdit(occurrence: EventOccurrence) {
        if occurrence.isFakeOccForEmptyToday {
            editMode = .add
        } else if occurrence.isOverride {
            if let override = occurrence.overrides.first(where: { $0.id == occurrence.id }) {
                editMode = .editOverride(override: override)
            }
        } else if let parent = allRecurringParentOccurrences.first(where: { $0.id == occurrence.eventId }) {
            let rule = occurrence.recurrence_rules.first(where: { $0.eventId == parent.eventId })
            if parent.isRecurring {
                editChoiceContext = EditChoiceContext(occurrence: occurrence, parentEvent: parent, rule: rule)
                showEditChoiceDialog = true
            } else {
                editMode = .editAll(event: parent, recurrenceRule: nil)
            }
        } else {
            editMode = .editAll(event: occurrence, recurrenceRule: nil)
        }
    }
    
    func handleEdit(occurrence: EventOccurrence, completion: (AddEditEventViewMode?, Bool) -> Void) {
        handleEdit(occurrence: occurrence)
        completion(editMode, showEditChoiceDialog)
    }
    
    func selectEditOnlyThisOccurrence() -> AddEditEventViewMode? {
        guard let ctx = editChoiceContext else { return nil }
        editMode = .editSingle(parentEvent: ctx.parentEvent, recurrenceRule: ctx.rule, occurrence: ctx.occurrence)
        showEditChoiceDialog = false
        editChoiceContext = nil
        return editMode
    }
    
    func selectEditAllOccurrences() -> AddEditEventViewMode? {
        guard let ctx = editChoiceContext else { return nil }
        editMode = .editAll(event: ctx.parentEvent, recurrenceRule: ctx.rule)
        showEditChoiceDialog = false
        editChoiceContext = nil
        return editMode
    }
    
    func selectEditFutureOccurrences() -> AddEditEventViewMode? {
        guard let ctx = editChoiceContext else { return nil }
        editMode = .editFuture(parentEvent: ctx.parentEvent, recurrenceRule: ctx.rule, startingFrom: ctx.occurrence)
        showEditChoiceDialog = false
        editChoiceContext = nil
        return editMode
    }
}
