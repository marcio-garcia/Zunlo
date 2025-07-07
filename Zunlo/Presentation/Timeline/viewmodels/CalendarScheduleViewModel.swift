//
//  CalendarScheduleViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/7/25.
//

import SwiftUI
import MiniSignalEye

class CalendarScheduleViewModel: ObservableObject {
    @Published var showAddSheet = false
    @Published var editMode: AddEditEventViewModel.Mode?
    @Published var showEditChoiceDialog = false
    @Published var editChoiceContext: EditChoiceContext?

    // For grouping and access
    @Published var eventOccurrences: [EventOccurrence] = []
    @Published var events: [Event] = []
    @Published var eventOverrides: [EventOverride] = []
    @Published var recurrenceRules: [RecurrenceRule] = []
    
    var repository: EventRepository
    let visibleRange: ClosedRange<Date>
    
    var occurObservID: UUID?
    var eventsObservID: UUID?
    var overridesObservID: UUID?
    var rulesObservID: UUID?
    
    struct EditChoiceContext {
        let occurrence: EventOccurrence
        let parentEvent: Event
        let rule: RecurrenceRule?
    }
    
    init(repository: EventRepository) {
        self.repository = repository
        let cal = Calendar.current
        let start = cal.date(byAdding: .month, value: -6, to: Date())!
        let end = cal.date(byAdding: .month, value: 6, to: Date())!
        self.visibleRange = start...end

        // Bind to repository data observers
        
        occurObservID = repository.eventOccurrences.observe(owner: self, onChange: { [weak self] occurrences in
            self?.eventOccurrences = occurrences
        })
        
        eventsObservID = repository.events.observe(owner: self, onChange: { [weak self] events in
            self?.events = events
        })
        
        overridesObservID = repository.eventOverrides.observe(owner: self, onChange: { [weak self] overrides in
            self?.eventOverrides = overrides
        })
        
        rulesObservID = repository.recurrenceRules.observe(owner: self, onChange: { [weak self] rules in
            self?.recurrenceRules = rules
        })
    }
    
    @MainActor
    func fetchEvents() async {
        do {
            try await repository.fetchAll(in: visibleRange)
        } catch {
            print(error)
        }
    }
    
    var occurrencesByMonthAndDay: [Date: [Date: [EventOccurrence]]] {
        let calendar = Calendar.current
        return Dictionary(
            grouping: eventOccurrences
        ) { occurrence in
            calendar.date(from: calendar.dateComponents([.year, .month], from: occurrence.startDate.startOfDay))!
        }
        .mapValues { occurrencesInMonth in
            Dictionary(
                grouping: occurrencesInMonth
            ) { $0.startDate.startOfDay }
            .mapValues { $0.sorted { $0.startDate < $1.startDate } }
        }
    }

    func handleEdit(occurrence: EventOccurrence) {
        if occurrence.isOverride {
            if let override = eventOverrides.first(where: { $0.id == occurrence.id }) {
                editMode = .editOverride(override: override)
            }
        } else if let parent = events.first(where: { $0.id == occurrence.eventId }) {
            let rule = recurrenceRules.first(where: { $0.eventId == parent.id })
            if parent.isRecurring {
                // Native SwiftUI confirmation dialog
                editChoiceContext = EditChoiceContext(occurrence: occurrence, parentEvent: parent, rule: rule)
                showEditChoiceDialog = true
            } else {
                editMode = .editAll(event: parent, recurrenceRule: nil)
            }
        }
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

    func handleDelete(occurrence: EventOccurrence) {
        // Implement actual delete logic here
    }
}

