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
        case editAll(event: EventOccurrence, recurrenceRule: RecurrenceRule?)
        case editSingle(parentEvent: EventOccurrence, recurrenceRule: RecurrenceRule?, occurrence: EventOccurrence)
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
    @Published var byMonthday: Set<Int> = []
    @Published var until: Date? = nil
    @Published var count: String = ""
    @Published var color: String = EventColor.yellow.rawValue
    @Published var isCancelled: Bool = false
    @Published var isProcessing: Bool = false
    @Published var reminderTriggers: [ReminderTrigger]?
    @Published var showDeleteConfirmation = false
    
    /// UI uses 0=Sunday...6=Saturday.
    /// calendarByWeekday maps to Calendar's 1=Sunday...7=Saturday.
    @Published var byWeekday: Set<Int> = []
    
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
    
    var isEditingAll: Bool {
        if case .editAll = mode { return true }
        return false
    }
    
    var calendarByWeekday: [Int] {
        return byWeekday.map { $0 + 1 }
    }
    
    func uiByWeekday(from calendarWeekdays: Set<Int>) -> Set<Int> {
        return Set(calendarWeekdays.map { ($0 + 6) % 7 })
    }
    
    private func loadFields() {
        switch mode {
        case .add:
            startDate = Date()
            updateEndDate()
            isRecurring = false
            recurrenceType = "daily"
            recurrenceInterval = 1
            byWeekday.removeAll()
            byMonthday.removeAll()
            until = nil
            count = ""
            color = EventColor.yellow.rawValue
            reminderTriggers = []
        case .editAll(let event, let rule):
            title = event.title
            notes = event.description ?? ""
            startDate = event.startDate
            if let end = event.endDate {
                endDate = end
            } else {
                updateEndDate()
            }
            location = event.location ?? ""
            isRecurring = event.isRecurring
            color = event.color.rawValue
            reminderTriggers = event.reminderTriggers ?? []
            if let rule = rule {
                recurrenceType = rule.freq
                recurrenceInterval = rule.interval
                byWeekday = uiByWeekday(from: Set(rule.byWeekday ?? []))
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
            if let end = occurrence.endDate {
                endDate = end
            } else {
                updateEndDate()
            }
            location = parent.location ?? ""
            color = parent.color.rawValue
            isCancelled = false
        case .editOverride(let override):
            title = override.overriddenTitle ?? ""
            notes = override.notes ?? ""
            startDate = override.overriddenStartDate ?? override.occurrenceDate
            if let end = override.overriddenEndDate {
                endDate = end
            } else {
                updateEndDate()
            }
            location = override.overriddenLocation ?? ""
            isCancelled = override.isCancelled
            color = override.color.rawValue
        }
    }
    
    func delete(completion: @escaping (Result<Void, Error>) -> Void) {
        isProcessing = true
        if case .editAll(let event, _) = mode {
            Task {
                do {
                    try await repository.delete(id: event.eventId, reminderTriggers: event.reminderTriggers)
                    isProcessing = true
                    completion(.success(()))
                } catch {
                    isProcessing = true
                    completion(.failure(error))
                }
            }
        }
    }
    
    func save(completion: @escaping (Result<Void, Error>) -> Void) {
        guard !title.isEmpty else { return }
        isProcessing = true

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
                isProcessing = false
                completion(.success(()))
            } catch {
                isProcessing = false
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
            updatedAt: now,
            color: EventColor(rawValue: color) ?? . yellow,
            reminderTriggers: reminderTriggers
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
                byWeekday: byWeekday.isEmpty ? nil : calendarByWeekday,
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
    
    private func editAll(event: EventOccurrence, oldRule: RecurrenceRule?) async throws {
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
            updatedAt: now,
            color: EventColor(rawValue: color) ?? . yellow,
            reminderTriggers: event.reminderTriggers
        )
        
        try await repository.update(updatedEvent)
        
        if isRecurring {
            let newRule = RecurrenceRule(
                id: oldRule?.id,
                eventId: event.id,
                freq: recurrenceType,
                interval: recurrenceInterval,
                byWeekday: byWeekday.isEmpty ? nil : calendarByWeekday,
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

    private func editSingle(parentEvent: EventOccurrence, occurrence: EventOccurrence) async throws {
        let now = Date()
        let override = EventOverride(
            id: nil,
            eventId: parentEvent.id,
            occurrenceDate: occurrence.startDate,
            overriddenTitle: title,
            overriddenStartDate: startDate,
            overriddenEndDate: endDate,
            overriddenLocation: location.isEmpty ? nil : location,
            isCancelled: isCancelled,
            notes: notes.isEmpty ? nil : notes,
            createdAt: now,
            updatedAt: now,
            color: EventColor(rawValue: color) ?? . yellow
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
            updatedAt: now,
            color: EventColor(rawValue: color) ?? . yellow
        )
        try await repository.updateOverride(updatedOverride)
    }
    
    func updateEndDate() {
        endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
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

extension AddEditEventViewModel {
    func sss() {
        
    }
}
