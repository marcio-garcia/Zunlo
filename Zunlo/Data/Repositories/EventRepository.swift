//
//  EventRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

public protocol EventStore {
    func makeEvent(title: String, start: Date, end: Date) -> Event?
    func fetchEvent(by id: UUID) async throws -> Event?
    func fetchOccurrences(for userId: UUID) async throws -> [EventOccurrence]
    func fetchOccurrences(id: UUID) async throws -> EventOccurrence?
    func fetchOccurrences(in range: Range<Date>) async throws -> [EventOccurrence]
    func upsert(_ event: Event) async throws
}

final public class EventRepository: EventStore {
    private let eventLocalStore: EventLocalStore
    private let recurrenceRuleLocalStore: RecurrenceRuleLocalStore
    private let eventOverrideLocalStore: EventOverrideLocalStore
    private let auth: AuthProviding
    
    private let reminderScheduler: ReminderScheduler<Event>
    private let calendar = Calendar.appDefault
    
    init(
        auth: AuthProviding,
        eventLocalStore: EventLocalStore,
        recurrenceRuleLocalStore: RecurrenceRuleLocalStore,
        eventOverrideLocalStore: EventOverrideLocalStore
    ) {
        self.auth = auth
        self.eventLocalStore = eventLocalStore
        self.recurrenceRuleLocalStore = recurrenceRuleLocalStore
        self.eventOverrideLocalStore = eventOverrideLocalStore
        self.reminderScheduler = ReminderScheduler()
    }

    public func fetchOccurrences(for userId: UUID) async throws -> [EventOccurrence] {
        do {
            let occurrences = try await eventLocalStore.fetchOccurrences(for: userId)
            let occ = occurrences.map { EventOccurrence(occ: $0) }
            return occ
        } catch {
            throw error
        }
    }
    
    public func fetchOccurrences(id: UUID) async throws -> EventOccurrence? {
        let occResp = try await eventLocalStore.fetchOccurrences(id: id)
        return occResp.map { EventOccurrence(occ: $0) }
    }
    
    public func fetchOccurrences(in range: Range<Date>) async throws -> [EventOccurrence] {
        guard await auth.isAuthorized(), let userId = auth.userId else { return [] }
        let rawOcc = try await fetchOccurrences(for: userId)
        return try EventOccurrenceService.generate(rawOccurrences: rawOcc, in: range, addFakeToday: false)
    }
    
    public func fetchEvent(by id: UUID) async throws -> Event? {
        if let event = try await eventLocalStore.fetch(id: id) {
            return Event(local: event)
        }
        return nil
    }
    
    func fetchEvent(filteredBy filter: EventFilter) async throws -> [Event] {
        let events = try await eventLocalStore.fetch(filteredBy: filter)
        return events.map { Event(local: $0) }
    }

    public func upsert(_ event: Event) async throws {
        guard await auth.isAuthorized() else { return }
        try await eventLocalStore.upsert(EventLocal(domain: event))
        reminderScheduler.cancelReminders(for: event)
        reminderScheduler.scheduleReminders(for: event)
    }
    
    func upsert(event: Event, rule: RecurrenceRule) async throws {
        try await eventLocalStore.upsert(event: EventLocal(domain: event), rule: rule)
    }

    func splitRecurringEvent(
        originalEventId: UUID,
        splitDate: Date,
        newEvent: Event
    ) async throws {
        guard await auth.isAuthorized() else { return }
        let _ = try await eventLocalStore.splitRecurringEvent(
            originalEventId: originalEventId,
            splitDate: splitDate,
            newEvent: EventLocal(domain: newEvent)
        )
    }

    func delete(id: UUID, reminderTriggers: [ReminderTrigger]? = nil) async throws {
        guard await auth.isAuthorized() else { return }
        try await eventLocalStore.delete(id: id)
        if let reminders = reminderTriggers {
            reminderScheduler.cancelReminders(itemId: id, reminderTriggers: reminders)
        }
    }

    func upsertRecurrenceRule(_ rule: RecurrenceRule) async throws {
        try await recurrenceRuleLocalStore.upsert(rule)
    }
    
    func upsertOverride(_ override: EventOverride) async throws {
        try await eventOverrideLocalStore.upsert(override)
    }
}

extension EventRepository {
    public func makeEvent(title: String, start: Date, end: Date) -> Event? {
        guard let userId = auth.userId else { return nil }
        return Event(
            id: UUID(),
            userId: userId,
            title: title,
            startDate: start,
            endDate: end,
            isRecurring: false,
            createdAt: Date(),
            updatedAt: Date(),
            color: .softOrange,
            needsSync: true)
    }
}

extension EventRepository {
    func add(_ input: AddEventInput) async throws {
        guard !input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EventError.validation(String(localized: "Title is required."))
        }
        let newEvent = Event(
            id: UUID(),
            userId: input.userId,
            title: input.title,
            notes: input.notes?.nilIfEmpty,
            startDate: input.startDate,
            endDate: input.endDate,
            isRecurring: input.isRecurring,
            location: input.location?.nilIfEmpty,
            createdAt: Date(),
            updatedAt: Date(),
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
                createdAt: Date(),
                updatedAt: Date(),
                version: nil
            )
            try await upsert(event: newEvent, rule: rule)
            
        } else {
            try await upsert(newEvent)
        }
    }

    func editAll(event: EventOccurrence, with input: EditEventInput, oldRule: RecurrenceRule?) async throws {
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
            updatedAt: Date(),
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
                createdAt: oldRule?.createdAt ?? Date(),
                updatedAt: Date(),
                version: oldRule?.version
            )
            try await upsert(event: updated, rule: rule)
            
        } else if let oldRule {
            try await upsert(event: updated, rule: oldRule)
            
        } else {
            try await upsert(updated)
        }
    }

    // Edit a single occurrence creating a new override
    func editSingle(parent: EventOccurrence, occurrence: EventOccurrence, with input: EditEventInput) async throws {
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
            createdAt: Date(),
            updatedAt: Date(),
            color: input.color,
            version: occurrence.version
        )
        try await upsertOverride(override)
    }

    // Edit an existing override
    func editOverride(_ override: EventOverride, with input: EditEventInput) async throws {
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
            updatedAt: Date(),
            color: input.color,
            version: override.version
        )
        try await upsertOverride(updated)
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
        try await splitRecurringEvent(
            originalEventId: parent.id,
            splitDate: occurrence.startDate,
            newEvent: newEvent
        )
    }
}
