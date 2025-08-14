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

    func add(_ input: AddEventInput) async throws {
        guard !input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EventError.validation(String(localized: "Title is required."))
        }
        let now = clock()
        let newEvent = Event(
            id: UUID(),
            userId: nil,
            title: input.title,
            notes: input.notes?.nilIfEmpty,
            startDate: input.startDate,
            endDate: input.endDate,
            isRecurring: input.isRecurring,
            location: input.location?.nilIfEmpty,
            createdAt: now,
            updatedAt: now,
            color: input.color,
            reminderTriggers: input.reminderTriggers,
            needsSync: false
        )

        // Orchestrate
        try await repo.upsert(newEvent)

        if input.isRecurring {
            let rule = RecurrenceRule(
                id: UUID(), // overriden by database
                eventId: newEvent.id,
                freq: input.recurrenceType!.rawValue,
                interval: input.recurrenceInterval ?? 1,
                byWeekday: input.byWeekday,
                byMonthday: input.byMonthday,
                byMonth: nil, // TODO: check if it is still in use
                until: input.until,
                count: input.count,
                createdAt: now,
                updatedAt: now
            )
            try await repo.upsertRecurrenceRule(rule)
        }
    }

    func editAll(event: EventOccurrence, with input: EditEventInput, oldRule: RecurrenceRule?) async throws {
        let now = clock()
        let updated = Event(
            id: event.id,
            userId: event.userId,
            title: input.title,
            notes: input.notes?.nilIfEmpty,
            startDate: input.startDate,
            endDate: input.endDate,
            isRecurring: input.isRecurring,
            location: input.location?.nilIfEmpty,
            createdAt: event.createdAt,
            updatedAt: now,
            color: input.color,
            reminderTriggers: input.reminderTriggers,
            needsSync: true
        )
        try await repo.upsert(updated)

        if input.isRecurring {
            let rule = RecurrenceRule(
                id: oldRule?.id ?? UUID(),
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
            try await repo.upsertRecurrenceRule(rule)
        } else if let oldRule {
            try await repo.deleteRecurrenceRule(oldRule)
        }
    }

    func editSingle(parent: EventOccurrence, occurrence: EventOccurrence, with input: EditEventInput) async throws {
        let now = clock()
        let override = EventOverride(
            id: UUID(),
            eventId: parent.id,
            occurrenceDate: occurrence.startDate,
            overriddenTitle: input.title,
            overriddenStartDate: input.startDate,
            overriddenEndDate: input.endDate,
            overriddenLocation: input.location?.nilIfEmpty,
            isCancelled: input.isCancelled,
            notes: input.notes?.nilIfEmpty,
            createdAt: now,
            updatedAt: now,
            color: input.color
        )
        try await repo.upsertOverride(override)
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
            isCancelled: input.isCancelled,
            notes: input.notes?.nilIfEmpty,
            createdAt: override.createdAt,
            updatedAt: now,
            color: input.color
        )
        try await repo.upsertOverride(updated)
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
