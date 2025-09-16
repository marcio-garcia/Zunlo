//
//  AddEditEventViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation
import SwiftUI

enum EventError: Error, CustomStringConvertible {
    case errorOnEventInsert
    case errorOnEventUpdate
    case errorOnEventDelete
    case validation(String)
    
    var description: String {
        switch self {
        case .errorOnEventInsert:
            return "Error on trying to insert event"
        case .errorOnEventUpdate:
            return "Error on trying to update event"
        case .errorOnEventDelete:
            return "Error on trying to delete event"
        case .validation(let msg):
            return "Validation error - \(msg)"
        }
    }
}

final class AddEditEventViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var notes: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(3600)
    @Published var location: String = ""
    @Published var isRecurring: Bool = false
    @Published var recurrenceType: String = RecurrenceFrequesncy.daily.rawValue
    @Published var recurrenceInterval: Int = 1
    @Published var byMonthday: Set<Int> = []
    @Published var until: Date? = nil
    @Published var count: String = ""
    @Published var color: String = EventColor.yellow.rawValue
    @Published var isCancelled: Bool = false
    @Published var isProcessing: Bool = false
    @Published var reminderTriggers: [ReminderTrigger]?
    @Published var showUntil: Bool = false
    
    /// UI uses 0=Sunday...6=Saturday.
    /// calendarByWeekday maps to Calendar's 1=Sunday...7=Saturday.
    @Published var byWeekday: Set<Int> = []
    
    let userId: UUID
    let mode: AddEditEventViewMode
    private let repo: EventRepository
    
    @MainActor let errorHandler = ErrorHandler()
    
    init(
        userId: UUID,
        mode: AddEditEventViewMode,
        repo: EventRepository
    ) {
        self.userId = userId
        self.mode = mode
        self.repo = repo
        loadFields()
    }

    func navigationTitle() -> String {
        switch mode {
        case .add: return String(localized: "Add event")
        case .editAll: return String(localized: "Edit")
        case .editSingle: return String(localized: "Edit")
        case .editOverride: return String(localized: "Edit")
        case .editFuture: return String(localized: "Edit")
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
    
    var isSaveDisabled: Bool {
        return title.isEmpty || isProcessing || (showUntil && until == nil)
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
            recurrenceType = RecurrenceFrequesncy.daily.rawValue
            recurrenceInterval = 1
            byWeekday.removeAll()
            byMonthday.removeAll()
            until = nil
            count = ""
            color = EventColor.yellow.rawValue
            reminderTriggers = []
        case .editAll(let event, let rule):
            title = event.title
            notes = event.notes ?? ""
            startDate = event.startDate
            endDate = event.endDate
            location = event.location ?? ""
            isRecurring = event.isRecurring
            color = event.color.rawValue
            reminderTriggers = event.reminderTriggers ?? []
            if let rule = rule {
                recurrenceType = rule.freq.rawValue
                recurrenceInterval = rule.interval
                byWeekday = uiByWeekday(from: Set(rule.byWeekday ?? []))
                rule.byMonthday?.forEach({ byMonthday.insert($0) })
                until = rule.until
                if until != nil {
                    showUntil = true
                }
                count = rule.count.map { String($0) } ?? ""
            } else {
                recurrenceType = RecurrenceFrequesncy.daily.rawValue
                recurrenceInterval = 1
                byWeekday.removeAll()
                byMonthday.removeAll()
                until = nil
                count = ""
            }
        case .editSingle(let parent, _, let occurrence):
            title = parent.title
            notes = parent.notes ?? ""
            startDate = occurrence.startDate
            endDate = occurrence.endDate
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
        case .editFuture(_, _, let startingFromOccurrence ):
            title = startingFromOccurrence.title
            notes = startingFromOccurrence.notes ?? ""
            startDate = startingFromOccurrence.startDate
            endDate = startingFromOccurrence.endDate
            location = startingFromOccurrence.location ?? ""
            color = startingFromOccurrence.color.rawValue
            isCancelled = startingFromOccurrence.isCancelled
            isRecurring = startingFromOccurrence.isRecurring
        }
    }
    
    func save() async -> Bool {
        guard !isProcessing, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        await MainActor.run { isProcessing = true }
        
        do {
            switch mode {
            case .add:
                try await repo.add(makeInput())
            case .editAll(let event, let oldRule):
                try await repo.editAll(event: event, with: makeInput(), oldRule: oldRule)
            case .editSingle(let parent, _, let occ):
                try await repo.editSingle(parent: parent, occurrence: occ, with: makeInput())
            case .editOverride(let ov):
                try await repo.editOverride(ov, with: makeInput())
            case .editFuture(let parent, _, let occ):
                try await repo.editFuture(parent: parent, startingFrom: occ, with: makeInput())
            }
            await MainActor.run { self.isProcessing = false }
            return true
        } catch {
            await MainActor.run { self.isProcessing = false }
            await errorHandler.handle(error)
            return false
        }
    }
    
    @MainActor
    func delete() async -> Bool {
        await MainActor.run { isProcessing = true }
        if case .editAll(let event, _) = mode {
            do {
                try await repo.delete(id: event.id)
                await MainActor.run { isProcessing = false }
                return true
            } catch {
                errorHandler.handle(error)
            }
        }
        await MainActor.run { isProcessing = false }
        return false
    }
    
    private func makeInput() -> AddEventInput {
        let untilDate = showUntil ? until : nil
        return AddEventInput(
            id: UUID(), // Not used by EventEditor
            userId: userId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes,
            startDate: startDate,
            endDate: endDate,
            isRecurring: isRecurring,
            location: location,
            color: EventColor(rawValue: color) ?? .yellow,
            reminderTriggers: reminderTriggers,
            recurrenceType: recurrenceType.rawValue,
            recurrenceInterval: recurrenceInterval,
            byWeekday: byWeekday.isEmpty ? nil : calendarByWeekday,
            byMonthday: byMonthday.isEmpty ? nil : Array(byMonthday),
            until: untilDate,
            count: Int(count),
            isCancelled: isCancelled
        )
    }
    
    func updateEndDate() {
        endDate = Calendar.appDefault.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
    }
}
