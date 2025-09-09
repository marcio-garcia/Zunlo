//
//  EventRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation
import MiniSignalEye

final public class EventRepository {
    private let eventLocalStore: EventLocalStore
    private let recurrenceRuleLocalStore: RecurrenceRuleLocalStore
    private let eventOverrideLocalStore: EventOverrideLocalStore
    private let auth: AuthProviding
    
    private let reminderScheduler: ReminderScheduler<Event>
    private let calendar = Calendar.appDefault
    
    var lastEventAction = Observable<LastEventAction>(.none)
    
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

    func fetchOccurrences(for userId: UUID) async throws -> [EventOccurrence] {
        do {
            let occurrences = try await eventLocalStore.fetchOccurrences(for: userId)
            let occ = occurrences.map { EventOccurrence(occ: $0) }
            lastEventAction.value = .fetch(occ)
            return occ
        } catch {
            lastEventAction.value = .error(error)
            throw error
        }
    }
    
    func fetchOccurrences(id: UUID) async throws -> EventOccurrence? {
        let occResp = try await eventLocalStore.fetchOccurrences(id: id)
        return occResp.map { EventOccurrence(occ: $0) }
    }
    
    func fetchEvent(by id: UUID) async throws -> Event? {
        if let event = try await eventLocalStore.fetch(id: id) {
            return Event(local: event)
        }
        return nil
    }
    
    func fetchEvent(filteredBy filter: EventFilter) async throws -> [Event] {
        let events = try await eventLocalStore.fetch(filteredBy: filter)
        return events.map { Event(local: $0) }
    }

    func upsert(_ event: Event) async throws {
        guard await auth.isAuthorized() else { return }
        try await eventLocalStore.upsert(EventLocal(domain: event))
        reminderScheduler.cancelReminders(for: event)
        reminderScheduler.scheduleReminders(for: event)
        lastEventAction.value = .update
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
        lastEventAction.value = .update
    }

    func delete(id: UUID, reminderTriggers: [ReminderTrigger]? = nil) async throws {
        guard await auth.isAuthorized() else { return }
        try await eventLocalStore.delete(id: id)
        if let reminders = reminderTriggers {
            reminderScheduler.cancelReminders(itemId: id, reminderTriggers: reminders)
        }
        lastEventAction.value = .delete
    }

    func upsertRecurrenceRule(_ rule: RecurrenceRule) async throws {
        try await recurrenceRuleLocalStore.upsert(rule)
    }
    
    func upsertOverride(_ override: EventOverride) async throws {
        try await eventOverrideLocalStore.upsert(override)
    }
}
