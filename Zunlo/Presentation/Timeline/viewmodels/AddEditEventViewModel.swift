//
//  AddEditEventViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation
import SwiftUI

enum EventError: Error {
    case errorOnEventInsert
    case errorOnEventUpdate
    case errorOnEventDelete
}

@MainActor
final class AddEditEventViewModel: ObservableObject {
    enum Mode {
        case add
        case editAll(event: Event, recurrenceRule: RecurrenceRule?)
        case editSingle(parentEvent: Event, recurrenceRule: RecurrenceRule?, occurrence: EventOccurrence)
        case editOverride(override: EventOverride)
    }

    @Published var title: String = ""
    @Published var notes: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(3600)
    @Published var location: String = ""
    @Published var isRecurring: Bool = false
    @Published var recurrenceType: String = "daily"
    @Published var recurrenceInterval: Int = 1
    @Published var byWeekday: Set<Int> = [] {
        didSet {
            print("🔍 byWeekday changed: \(oldValue) → \(byWeekday)")
        }
    }
    @Published var byMonthday: Set<Int> = []
    @Published var until: Date? = nil
    @Published var count: String = ""
    @Published var isCancelled: Bool = false
    @Published var isSaving: Bool = false

    let mode: Mode
    let repository: EventRepository

    init(mode: Mode, repository: EventRepository) {
        self.mode = mode
        self.repository = repository
        loadFields()
    }

    func navigationTitle() -> String {
        switch mode {
        case .add: return "Add Event"
        case .editAll: return "Edit All Events"
        case .editSingle: return "Edit This Occurrence"
        case .editOverride: return "Edit This Occurrence"
        }
    }

    var showsRecurrenceSection: Bool {
        switch mode {
        case .add, .editAll: return true
        default: return false
        }
    }

    var showsCancelSection: Bool { true }
    
    var isEditingSingleOrOverride: Bool {
        if case .editSingle = mode { return true }
        if case .editOverride = mode { return true }
        return false
    }
    
    private func loadFields() {
        switch mode {
        case .add:
            endDate = startDate.addingTimeInterval(3600)
            isRecurring = false
            recurrenceType = "daily"
            recurrenceInterval = 1
            byWeekday.removeAll()
            byMonthday.removeAll()
            until = nil
            count = ""
        case .editAll(let event, let rule):
            title = event.title
            notes = event.description ?? ""
            startDate = event.startDate
            endDate = event.endDate ?? event.startDate.addingTimeInterval(3600)
            location = event.location ?? ""
            isRecurring = event.isRecurring
            if let rule = rule {
                recurrenceType = rule.freq
                recurrenceInterval = rule.interval
                rule.byWeekday?.forEach({ byWeekday.insert($0) })
                rule.byMonthday?.forEach({ byMonthday.insert($0) })
                until = rule.until
                count = rule.count.map { String($0) } ?? ""
            } else {
                recurrenceType = "daily"
                recurrenceInterval = 1
                byWeekday.removeAll()
                byMonthday.removeAll()
                until = nil
                count = ""
            }
        case .editSingle(let parent, _, let occurrence):
            title = parent.title
            notes = parent.description ?? ""
            startDate = occurrence.startDate
            endDate = occurrence.endDate ?? occurrence.startDate.addingTimeInterval(3600)
            location = parent.location ?? ""
            isCancelled = false
        case .editOverride(let override):
            title = override.overriddenTitle ?? ""
            notes = override.notes ?? ""
            startDate = override.overriddenStartDate ?? override.occurrenceDate
            endDate = override.overriddenEndDate ?? (override.overriddenStartDate?.addingTimeInterval(3600) ?? override.occurrenceDate.addingTimeInterval(3600))
            location = override.overriddenLocation ?? ""
            isCancelled = override.isCancelled
        }
    }
    
    func save(completion: @escaping (Result<Void, Error>) -> Void) {
        guard !title.isEmpty else { return }
        isSaving = true

        Task {
            do {
                switch mode {
                case .add:
                    try await addEvent()
                case .editAll(let event, let oldRule):
                    try await editAll(event: event, oldRule: oldRule)
                case .editSingle(let parent, _, let occurrence):
                    try await editSingle(parentEvent: parent, occurrence: occurrence)
                case .editOverride(let override):
                    try await editOverride(override: override)
                }
                isSaving = false
                completion(.success(()))
            } catch {
                isSaving = false
                completion(.failure(error))
            }
        }
    }
    
    private func addEvent() async throws {
        let now = Date()
        let newEvent = Event(
            id: nil,
            userId: nil,
            title: title,
            description: notes.isEmpty ? nil : notes,
            startDate: startDate,
            endDate: endDate,
            isRecurring: isRecurring,
            location: location.isEmpty ? nil : location,
            createdAt: now,
            updatedAt: now
        )
        
        let addedEvents = try await repository.save(newEvent)
        guard let event = addedEvents.first, let newEventId = event.id else {
            throw EventError.errorOnEventInsert
        }
        
        if isRecurring {
            let newRule = RecurrenceRule(
                id: UUID(),
                eventId: newEventId,
                freq: recurrenceType,
                interval: recurrenceInterval,
                byWeekday: byWeekday.isEmpty ? nil : Array(byWeekday),
                byMonthday: byMonthday.isEmpty ? nil : Array(byMonthday),
                byMonth: nil,
                until: until,
                count: Int(count),
                createdAt: now,
                updatedAt: now
            )
            try await repository.saveRecurrenceRule(newRule)
        }
    }
    
    private func editAll(event: Event, oldRule: RecurrenceRule?) async throws {
        guard let eventId = event.id else {
            throw EventError.errorOnEventUpdate
        }
        
        let now = Date()
        let updatedEvent = Event(
            id: event.id,
            userId: event.userId,
            title: title,
            description: notes.isEmpty ? nil : notes,
            startDate: startDate,
            endDate: endDate,
            isRecurring: isRecurring,
            location: location.isEmpty ? nil : location,
            createdAt: event.createdAt,
            updatedAt: now
        )
        
        try await repository.update(updatedEvent)
        
        if isRecurring {
            let newRule = RecurrenceRule(
                id: oldRule?.id,
                eventId: eventId,
                freq: recurrenceType,
                interval: recurrenceInterval,
                byWeekday: byWeekday.isEmpty ? nil : Array(byWeekday),
                byMonthday: byMonthday.isEmpty ? nil : Array(byMonthday),
                byMonth: nil,
                until: until,
                count: Int(count),
                createdAt: oldRule?.createdAt ?? now,
                updatedAt: now
            )
            if oldRule != nil {
                try await repository.updateRecurrenceRule(newRule)
            } else {
                try await repository.saveRecurrenceRule(newRule)
            }
        } else if let oldRule = oldRule {
            try await repository.deleteRecurrenceRule(oldRule)
        }
    }

    private func editSingle(parentEvent: Event, occurrence: EventOccurrence) async throws {
        guard let parentEventId = parentEvent.id else {
            throw EventError.errorOnEventUpdate
        }
        
        let now = Date()
        let override = EventOverride(
            id: nil,
            eventId: parentEventId,
            occurrenceDate: occurrence.startDate,
            overriddenTitle: title,
            overriddenStartDate: startDate,
            overriddenEndDate: endDate,
            overriddenLocation: location.isEmpty ? nil : location,
            isCancelled: isCancelled,
            notes: notes.isEmpty ? nil : notes,
            createdAt: now,
            updatedAt: now
        )
        try await repository.saveOverride(override)
    }
    
    private func editOverride(override: EventOverride) async throws {
        let now = Date()
        let updatedOverride = EventOverride(
            id: override.id,
            eventId: override.eventId,
            occurrenceDate: override.occurrenceDate,
            overriddenTitle: title,
            overriddenStartDate: startDate,
            overriddenEndDate: endDate,
            overriddenLocation: location.isEmpty ? nil : location,
            isCancelled: isCancelled,
            notes: notes.isEmpty ? nil : notes,
            createdAt: override.createdAt,
            updatedAt: now
        )
        try await repository.updateOverride(updatedOverride)
    }
}

extension AddEditEventViewModel.Mode: Identifiable {
    var id: String {
        switch self {
        case .add: return "add"
        case .editAll(let event, _): return "editAll-\(event.id)"
        case .editSingle(let parent, _, let occurrence):
            return "editSingle-\(parent.id)-\(occurrence.startDate.timeIntervalSince1970)"
        case .editOverride(let override): return "editOverride-\(override.id)"
        }
    }
}
