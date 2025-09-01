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
    private let eventRemoteStore: EventRemoteStore
    private let recurrenceRuleLocalStore: RecurrenceRuleLocalStore
    private let recurrenceRuleRemoteStore: RecurrenceRuleRemoteStore
    private let eventOverrideLocalStore: EventOverrideLocalStore
    private let eventOverrideRemoteStore: EventOverrideRemoteStore
    private let auth: AuthProviding
    
    private let reminderScheduler: ReminderScheduler<Event>
    private let calendar = Calendar.appDefault
    
    var lastEventAction = Observable<LastEventAction>(.none)
    
    init(
        auth: AuthProviding,
        eventLocalStore: EventLocalStore,
        eventRemoteStore: EventRemoteStore,
        recurrenceRuleLocalStore: RecurrenceRuleLocalStore,
        recurrenceRuleRemoteStore: RecurrenceRuleRemoteStore,
        eventOverrideLocalStore: EventOverrideLocalStore,
        eventOverrideRemoteStore: EventOverrideRemoteStore
    ) {
        self.auth = auth
        self.eventLocalStore = eventLocalStore
        self.eventRemoteStore = eventRemoteStore
        self.recurrenceRuleLocalStore = recurrenceRuleLocalStore
        self.recurrenceRuleRemoteStore = recurrenceRuleRemoteStore
        self.eventOverrideLocalStore = eventOverrideLocalStore
        self.eventOverrideRemoteStore = eventOverrideRemoteStore
        self.reminderScheduler = ReminderScheduler()
    }

    // MARK: - Fetch & Compose All (from local, for UI)

//    func fetchAll(in range: ClosedRange<Date>? = nil) async throws -> [EventOccurrence] {
//        do {
//            let eventsLocal = try await eventLocalStore.fetchAll()
//            if eventsLocal.isEmpty {
//                try await synchronize()
//            } else {
//                try await fetchLocal(in: range)
//            }
//        } catch {
//            self.events.value = []
//            self.recurrenceRules.value = []
//            self.eventOverrides.value = []
//            print("Failed to fetch data: \(error)")
//        }
//    }
    
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
    
    func fetchEvent(startAt: Date) async throws -> Event? {
        guard await auth.isAuthorized(), let userId = auth.userId else {
            throw LocalDBError.unauthorized
        }
        if let event = try await eventLocalStore.fetch(userId: userId, startAt: startAt) {
            return Event(local: event)
        }
        return nil
    }
    
    func fetchEvent(filteredBy filter: EventFilter) async throws -> [Event] {
        let events = try await eventLocalStore.fetch(filteredBy: filter)
        return events.map { Event(local: $0) }
    }
    
    private func fetchLocalEvents() async throws -> [Event] {
        let events = try await eventLocalStore.fetchAll()
        return events.map { Event(local: $0) }
    }
    
    private func fetchLocalRules() async throws -> [RecurrenceRule] {
        try await recurrenceRuleLocalStore.fetchAll().map { RecurrenceRule(local: $0) }
    }
    
    private func fetchLocalOverrides() async throws -> [EventOverride] {
        try await eventOverrideLocalStore.fetchAll().map { EventOverride(local: $0) }
    }

    // MARK: - CRUD for Events

    func upsert(_ event: Event) async throws {
        guard await auth.isAuthorized() else { return }
        try await eventLocalStore.upsert(EventLocal(domain: event))
        reminderScheduler.cancelReminders(for: event)
        reminderScheduler.scheduleReminders(for: event)
        lastEventAction.value = .update
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

    func apply(rows: [EventRemote]) async throws {
        guard await auth.isAuthorized() else { return }
        try await eventLocalStore.apply(rows: rows)
    }

    // MARK: - CRUD for RecurrenceRule

    func saveRecurrenceRule(_ rule: RecurrenceRule) async throws {
        try await recurrenceRuleLocalStore.save(rule)
    }

    func upsertRecurrenceRule(_ rule: RecurrenceRule) async throws {
        try await recurrenceRuleLocalStore.upsert(rule)
    }

    func deleteRecurrenceRule(_ rule: RecurrenceRule) async throws {
        try await recurrenceRuleLocalStore.delete(id: rule.id)
    }
    
    func apply(rows: [RecurrenceRuleRemote]) async throws {
        try await recurrenceRuleLocalStore.apply(rows: rows)
    }

    // MARK: - CRUD for EventOverride

    func saveOverride(_ override: EventOverride) async throws {
        try await eventOverrideLocalStore.save(override)
    }

    func upsertOverride(_ override: EventOverride) async throws {
        try await eventOverrideLocalStore.upsert(override)
    }

    func deleteOverride(_ override: EventOverride) async throws {
        try await eventOverrideLocalStore.delete(id: override.id)
    }
    
    func apply(rows: [EventOverrideRemote]) async throws {
        try await eventOverrideLocalStore.apply(rows: rows)
    }

    // MARK: - Batch Delete & Sync

    func deleteAllEvents(userId: UUID) async throws {
        try await eventLocalStore.deleteAll(for: userId)
        // Optionally delete recurrence rules and overrides for this user as well
    }

    /// Fetch everything from remote and overwrite local cache
//    func synchronize() async throws {
//        let remoteEvents = try await eventRemoteStore.fetchAll()
//        let remoteRules = try await recurrenceRuleRemoteStore.fetchAll()
//        let remoteOverrides = try await eventOverrideRemoteStore.fetchAll()
//
//        try await eventLocalStore.deleteAll()
//        try await recurrenceRuleLocalStore.deleteAll()
//        try await eventOverrideLocalStore.deleteAll()
//
//        for e in remoteEvents { try await eventLocalStore.save(e) }
//        for r in remoteRules { try await recurrenceRuleLocalStore.save(r) }
//        for o in remoteOverrides { try await eventOverrideLocalStore.save(o) }
//    }
}

extension EventRepository {
    func upsert(event: Event, rule: RecurrenceRule) async throws {
        try await eventLocalStore.upsert(event: EventLocal(domain: event), rule: rule)
    }
}
