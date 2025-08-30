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
            userId: input.userId,
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
            needsSync: true,
            version: nil
        )

        if input.isRecurring {
            let rule = RecurrenceRule(
                id: UUID(), // overriden by database
                eventId: newEvent.id,
                freq: RecurrenceFrequesncy(rawValue: input.recurrenceType ?? "") ?? .daily,
                interval: input.recurrenceInterval ?? 1,
                byWeekday: input.byWeekday,
                byMonthday: input.byMonthday,
                byMonth: nil, // TODO: check if it is still in use
                until: input.until,
                count: input.count,
                createdAt: now,
                updatedAt: now,
                version: nil
            )
            try await repo.upsert(event: newEvent, rule: rule)
            
        } else {
            try await repo.upsert(newEvent)
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
            needsSync: true,
            version: event.version
        )

        if input.isRecurring {
            let rule = RecurrenceRule(
                id: oldRule?.id ?? UUID(),
                eventId: event.id,
                freq: RecurrenceFrequesncy(rawValue: input.recurrenceType ?? "") ?? .daily,
                interval: input.recurrenceInterval ?? 1,
                byWeekday: input.byWeekday,
                byMonthday: input.byMonthday,
                byMonth: nil,
                until: input.until,
                count: input.count,
                createdAt: oldRule?.createdAt ?? now,
                updatedAt: now,
                version: oldRule?.version
            )
            try await repo.upsert(event: updated, rule: rule)
            
        } else if let oldRule {
            try await repo.upsert(event: updated, rule: oldRule)
            
        } else {
            try await repo.upsert(updated)
        }
    }

    // Edit a single occurrence creating a new override
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
            color: input.color,
            version: occurrence.version
        )
        try await repo.upsertOverride(override)
    }

    // Edit an existing override
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
            color: input.color,
            version: override.version
        )
        try await repo.upsertOverride(updated)
    }

    func editFuture(parent: EventOccurrence, startingFrom occurrence: EventOccurrence, with input: EditEventInput) async throws {
        let newEvent = Event(
            id: UUID(),
            userId: occurrence.userId,
            title: input.title,
            notes: input.notes?.nilIfEmpty,
            startDate: input.startDate,
            endDate: input.endDate,
            isRecurring: input.isRecurring,
            location: input.location,
            createdAt: Date(),
            updatedAt: Date(),
            color: input.color,
            reminderTriggers: input.reminderTriggers,
            deletedAt: nil,
            needsSync: true,
            version: nil
        )
        try await repo.splitRecurringEvent(
            originalEventId: parent.id,
            splitDate: occurrence.startDate,
            newEvent: newEvent
        )
    }
    
    func delete(event: EventOccurrence) async throws {
        try await repo.delete(id: event.eventId, reminderTriggers: event.reminderTriggers)
    }
}
