//
//  EventEditor.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

final class EventEditor: EventEditorService {
    private let repo: EventRepository
    private let clock: () -> Date

    init(repo: EventRepository, clock: @escaping () -> Date = Date.init) {
        self.repo = repo
        self.clock = clock
    }

    func add(_ input: AddEventInput) async throws -> Event {
        guard !input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EventError.validation(String(localized: "Title is required."))
        }
        let now = clock()
        let newEvent = Event(
            id: nil, userId: nil,
            title: input.title,
            description: input.notes?.nilIfEmpty,
            startDate: input.startDate,
            endDate: input.endDate,
            isRecurring: input.isRecurring,
            location: input.location?.nilIfEmpty,
            createdAt: now, updatedAt: now,
            color: input.color,
            reminderTriggers: input.reminderTriggers
        )

        // Orchestrate
        let created = try await repo.save(newEvent)
        guard let event = created.first, let eventID = event.id else { throw EventError.errorOnEventInsert }

        if input.isRecurring {
            let rule = RecurrenceRule(
                id: UUID(),
                eventId: eventID,
                freq: input.recurrenceType!.rawValue,
                interval: input.recurrenceInterval ?? 1,
                byWeekday: input.byWeekday,
                byMonthday: input.byMonthday,
                byMonth: nil,
                until: input.until,
                count: input.count,
                createdAt: now,
                updatedAt: now
            )
            try await repo.saveRecurrenceRule(rule)
        }
        return event
    }

    func editAll(event: EventOccurrence, with input: EditEventInput, oldRule: RecurrenceRule?) async throws {
        let now = clock()
        let updated = Event(
            id: event.id, userId: event.userId,
            title: input.title,
            description: input.notes?.nilIfEmpty,
            startDate: input.startDate, endDate: input.endDate,
            isRecurring: input.isRecurring,
            location: input.location?.nilIfEmpty,
            createdAt: event.createdAt, updatedAt: now,
            color: input.color,
            reminderTriggers: input.reminderTriggers
        )
        try await repo.update(updated)

        if input.isRecurring {
            let rule = RecurrenceRule(
                id: oldRule?.id,
                eventId: event.id,
                freq: input.recurrenceType!.rawValue,
                interval: input.recurrenceInterval ?? 1,
                byWeekday: input.byWeekday,
                byMonthday: input.byMonthday,
                byMonth: nil,
                until: input.until,
                count: input.count,
                createdAt: oldRule?.createdAt ?? now,
                updatedAt: now
            )
            if oldRule != nil { try await repo.updateRecurrenceRule(rule) }
            else { try await repo.saveRecurrenceRule(rule) }
        } else if let oldRule { try await repo.deleteRecurrenceRule(oldRule) }
    }

    func editSingle(parent: EventOccurrence, occurrence: EventOccurrence, with input: EditEventInput) async throws {
        let now = clock()
        let override = EventOverride(
            id: nil,
            eventId: parent.id,
            occurrenceDate: occurrence.startDate,
            overriddenTitle: input.title,
            overriddenStartDate: input.startDate,
            overriddenEndDate: input.endDate,
            overriddenLocation: input.location?.nilIfEmpty,
            isCancelled: false, // or pass via input if needed
            notes: input.notes?.nilIfEmpty,
            createdAt: now, updatedAt: now,
            color: input.color
        )
        try await repo.saveOverride(override)
    }

    func editOverride(_ override: EventOverride, with input: EditEventInput) async throws {
        let now = clock()
        let updated = EventOverride(
            id: override.id,
            eventId: override.eventId,
            occurrenceDate: override.occurrenceDate,
            overriddenTitle: input.title,
            overriddenStartDate: input.startDate,
            overriddenEndDate: input.endDate,
            overriddenLocation: input.location?.nilIfEmpty,
            isCancelled: override.isCancelled,
            notes: input.notes?.nilIfEmpty,
            createdAt: override.createdAt, updatedAt: now,
            color: input.color
        )
        try await repo.updateOverride(updated)
    }

    func editFuture(parent: EventOccurrence, startingFrom occurrence: EventOccurrence, with input: EditEventInput) async throws {
        let data = SplitRecurringEventRemote.NewEventData(
            userId: occurrence.userId,
            title: input.title,
            description: input.notes?.nilIfEmpty,
            startDatetime: input.startDate,
            endDatetime: input.endDate,
            isRecurring: input.isRecurring,
            location: input.location?.nilIfEmpty,
            color: input.color,
            reminderTriggers: input.reminderTriggers
        )
        let split = SplitRecurringEventRemote(
            originalEventId: parent.id,
            splitFromDate: occurrence.startDate,
            newEventData: data
        )
        try await repo.splitRecurringEvent(split)
    }
    
    func delete(event: EventOccurrence) async throws {
        try await repo.delete(id: event.eventId, reminderTriggers: event.reminderTriggers)
    }
}
