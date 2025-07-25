//
//  EventRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation
import MiniSignalEye

final class EventRepository {
    // Raw domain entities (may be useful for some advanced features)
    private(set) var events = Observable<[Event]>([])
    private(set) var recurrenceRules = Observable<[RecurrenceRule]>([])
    private(set) var eventOverrides = Observable<[EventOverride]>([])
    private(set) var occurrences = Observable<[EventOccurrence]>([])
    
    // Stores
    private let eventLocalStore: EventLocalStore
    private let eventRemoteStore: EventRemoteStore
    private let recurrenceRuleLocalStore: RecurrenceRuleLocalStore
    private let recurrenceRuleRemoteStore: RecurrenceRuleRemoteStore
    private let eventOverrideLocalStore: EventOverrideLocalStore
    private let eventOverrideRemoteStore: EventOverrideRemoteStore
    
    private let reminderScheduler: ReminderScheduler<Event>
    
    init(
        eventLocalStore: EventLocalStore,
        eventRemoteStore: EventRemoteStore,
        recurrenceRuleLocalStore: RecurrenceRuleLocalStore,
        recurrenceRuleRemoteStore: RecurrenceRuleRemoteStore,
        eventOverrideLocalStore: EventOverrideLocalStore,
        eventOverrideRemoteStore: EventOverrideRemoteStore
    ) {
        self.eventLocalStore = eventLocalStore
        self.eventRemoteStore = eventRemoteStore
        self.recurrenceRuleLocalStore = recurrenceRuleLocalStore
        self.recurrenceRuleRemoteStore = recurrenceRuleRemoteStore
        self.eventOverrideLocalStore = eventOverrideLocalStore
        self.eventOverrideRemoteStore = eventOverrideRemoteStore
        self.reminderScheduler = ReminderScheduler()
    }

    // MARK: - Fetch & Compose All (from local, for UI)

    func fetchAll(in range: ClosedRange<Date>? = nil) async throws {
        occurrences.value = try await fetchRemote()
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
    }
    
    private func fetchLocal(in range: ClosedRange<Date>? = nil) async throws {
        do {
            self.events.value = try await eventLocalStore.fetchAll()
            self.recurrenceRules.value = try await recurrenceRuleLocalStore.fetchAll()
            self.eventOverrides.value = try await eventOverrideLocalStore.fetchAll()
        } catch {
            self.events.value = []
            self.recurrenceRules.value = []
            self.eventOverrides.value = []
            print("Failed to fetch all local data: \(error)")
        }
    }
    
    private func fetchRemote() async throws -> [EventOccurrence] {
        let occurrences = try await eventRemoteStore.fetchOccurrences()
        return occurrences.map { EventOccurrence(remote: $0) }
    }

    // MARK: - CRUD for Events

    func save(_ event: Event) async throws -> [Event] {
        let savedRemote = try await eventRemoteStore.save(EventRemote(domain: event))
        for remote in savedRemote {
            try await eventLocalStore.save(remote)
            reminderScheduler.scheduleReminders(for: Event(remote: remote))
        }
        occurrences.value = try await fetchRemote()
        return savedRemote.compactMap { Event(remote: $0) }
    }

    func update(_ event: Event) async throws {
        let updatedRemote = try await eventRemoteStore.update(EventRemote(domain: event))
        for remote in updatedRemote {
            try await eventLocalStore.update(remote)
            reminderScheduler.cancelReminders(for: Event(remote: remote))
            reminderScheduler.scheduleReminders(for: Event(remote: remote))
        }
        occurrences.value = try await fetchRemote()
    }

    func delete(id: UUID, reminderTriggers: [ReminderTrigger]? = nil) async throws {
        let deleted = try await eventRemoteStore.delete(id: id)
        for event in deleted {
            if let id = event.id {
                try await eventLocalStore.delete(id: id)
            }
        }
        if let triggers = reminderTriggers {
            reminderScheduler.cancelReminders(itemId: id, reminderTriggers: triggers)
        }
        occurrences.value = try await fetchRemote()
    }

    // MARK: - CRUD for RecurrenceRule

    func saveRecurrenceRule(_ rule: RecurrenceRule) async throws {
        let inserted = try await recurrenceRuleRemoteStore.save(RecurrenceRuleRemote(domain: rule))
        for rule in inserted {
            try await recurrenceRuleLocalStore.save(rule)
        }
        occurrences.value = try await fetchRemote()
    }

    func updateRecurrenceRule(_ rule: RecurrenceRule) async throws {
        let updated = try await recurrenceRuleRemoteStore.update(RecurrenceRuleRemote(domain: rule))
        for rule in updated {
            try await recurrenceRuleLocalStore.update(rule)
        }
        occurrences.value = try await fetchRemote()
    }

    func deleteRecurrenceRule(_ rule: RecurrenceRule) async throws {
        let deleted = try await recurrenceRuleRemoteStore.delete(RecurrenceRuleRemote(domain: rule))
        for rule in deleted {
            if let id = rule.id {
                try await recurrenceRuleLocalStore.delete(id: id)
            }
        }
        occurrences.value = try await fetchRemote()
    }

    // MARK: - CRUD for EventOverride

    func saveOverride(_ override: EventOverride) async throws {
        let inserted = try await eventOverrideRemoteStore.save(EventOverrideRemote(domain: override))
        for ov in inserted {
            try await eventOverrideLocalStore.save(ov)
        }
        occurrences.value = try await fetchRemote()
    }

    func updateOverride(_ override: EventOverride) async throws {
        let updated = try await eventOverrideRemoteStore.update(EventOverrideRemote(domain: override))
        for ov in updated {
            try await eventOverrideLocalStore.update(ov)
        }
        occurrences.value = try await fetchRemote()
    }

    func deleteOverride(_ override: EventOverride) async throws {
        let deleted = try await eventOverrideRemoteStore.delete(EventOverrideRemote(domain: override))
        for del in deleted {
            if let id = del.id {
                try await eventOverrideLocalStore.delete(id: id)
            }
        }
        occurrences.value = try await fetchRemote()
    }

    // MARK: - Batch Delete & Sync

    func deleteAllEvents(userId: UUID) async throws {
        _ = try await eventRemoteStore.deleteAll(for: userId)
        try await eventLocalStore.deleteAll(for: userId)
        // Optionally delete recurrence rules and overrides for this user as well
        occurrences.value = try await fetchRemote()
    }

    /// Fetch everything from remote and overwrite local cache
    func synchronize() async throws {
        let remoteEvents = try await eventRemoteStore.fetchAll()
        let remoteRules = try await recurrenceRuleRemoteStore.fetchAll()
        let remoteOverrides = try await eventOverrideRemoteStore.fetchAll()

        try await eventLocalStore.deleteAll()
        try await recurrenceRuleLocalStore.deleteAll()
        try await eventOverrideLocalStore.deleteAll()

        for e in remoteEvents { try await eventLocalStore.save(e) }
        for r in remoteRules { try await recurrenceRuleLocalStore.save(r) }
        for o in remoteOverrides { try await eventOverrideLocalStore.save(o) }

        try await fetchAll()
    }
}

// Helper to remove duplicates by value
extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
