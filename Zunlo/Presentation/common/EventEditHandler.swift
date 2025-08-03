//
//  EventEditHandler.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/2/25.
//

import SwiftUI

final class EventEditHandler: ObservableObject {
    @Published var editMode: AddEditEventViewMode?
    @Published var showEditChoiceDialog = false
    var editChoiceContext: EditChoiceContext?

    var allRecurringParentOccurrences: [EventOccurrence] = []

    func handleEdit(occurrence: EventOccurrence) {
        if occurrence.isOverride {
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
    
    func selectEditOnlyThisOccurrence() {
        guard let ctx = editChoiceContext else { return }
        editMode = .editSingle(parentEvent: ctx.parentEvent, recurrenceRule: ctx.rule, occurrence: ctx.occurrence)
        showEditChoiceDialog = false
        editChoiceContext = nil
    }
    
    func selectEditAllOccurrences() {
        guard let ctx = editChoiceContext else { return }
        editMode = .editAll(event: ctx.parentEvent, recurrenceRule: ctx.rule)
        showEditChoiceDialog = false
        editChoiceContext = nil
    }
}
