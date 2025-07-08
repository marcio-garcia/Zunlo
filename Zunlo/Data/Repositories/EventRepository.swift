//
//  EventRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation
import MiniSignalEye

final class EventRepository {
    // Flat list of all event instances, ready for UI
    private(set) var eventOccurrences = Observable<[EventOccurrence]>([])
    
    // Raw domain entities (may be useful for some advanced features)
    private(set) var events = Observable<[Event]>([])
    private(set) var recurrenceRules = Observable<[RecurrenceRule]>([])
    private(set) var eventOverrides = Observable<[EventOverride]>([])

    // Stores
    private let eventLocalStore: EventLocalStore
    private let eventRemoteStore: EventRemoteStore
    private let recurrenceRuleLocalStore: RecurrenceRuleLocalStore
    private let recurrenceRuleRemoteStore: RecurrenceRuleRemoteStore
    private let eventOverrideLocalStore: EventOverrideLocalStore
    private let eventOverrideRemoteStore: EventOverrideRemoteStore

    var occurrenceObservable = Observable<[EventOccurrence]>([])
    
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
    }

    // MARK: - Fetch & Compose All (from local, for UI)

    func fetchAll(in range: ClosedRange<Date>? = nil) async throws {
        do {
            let eventsLocal = try await eventLocalStore.fetchAll()
            if eventsLocal.isEmpty {
                try await synchronize()
            } else {
                try await fetchLocal(in: range)
            }
        } catch {
            self.events.value = []
            self.recurrenceRules.value = []
            self.eventOverrides.value = []
            self.eventOccurrences.value = []
            print("Failed to fetch data: \(error)")
        }
    }
    
    private func fetchLocal(in range: ClosedRange<Date>? = nil) async throws {
        do {
            self.events.value = try await eventLocalStore.fetchAll()
            self.recurrenceRules.value = try await recurrenceRuleLocalStore.fetchAll()
            self.eventOverrides.value = try await eventOverrideLocalStore.fetchAll()
            self.eventOccurrences.value = try composeOccurrences(in: range)
        } catch {
            self.events.value = []
            self.recurrenceRules.value = []
            self.eventOverrides.value = []
            self.eventOccurrences.value = []
            print("Failed to fetch all local data: \(error)")
        }
    }

    // MARK: - Compose occurrences for the UI

    func composeOccurrences(in range: ClosedRange<Date>? = nil) throws -> [EventOccurrence] {
        let usedRange = range ?? defaultDateRange()
        return try EventOccurrenceService.generate(
            events: self.events.value,
            rules: self.recurrenceRules.value,
            overrides: self.eventOverrides.value,
            in: usedRange
        )
    }

    private func defaultDateRange() -> ClosedRange<Date> {
        let cal = Calendar.current
        let start = cal.date(byAdding: .month, value: -12, to: Date())!
        let end = cal.date(byAdding: .month, value: 12, to: Date())!
        return start...end
    }

    // MARK: - CRUD for Events

    func save(_ event: Event) async throws -> [Event] {
        let inserted = try await eventRemoteStore.save(EventRemote(domain: event))
        for event in inserted {
            try await eventLocalStore.save(event)
        }
        try await fetchLocal()
        return inserted.compactMap { Event(remote: $0) }
    }

    func update(_ event: Event) async throws {
        let updated = try await eventRemoteStore.update(EventRemote(domain: event))
        for event in updated {
            try await eventLocalStore.update(event)
        }
        try await fetchLocal()
    }

    func delete(_ event: Event) async throws {
        guard let id = event.id else { return }
        let deleted = try await eventRemoteStore.delete(EventRemote(domain: event))
        for event in deleted {
            try await eventLocalStore.delete(id: id)
        }
        try await fetchLocal()
    }

    // MARK: - CRUD for RecurrenceRule

    func saveRecurrenceRule(_ rule: RecurrenceRule) async throws {
        let inserted = try await recurrenceRuleRemoteStore.save(RecurrenceRuleRemote(domain: rule))
        for rule in inserted {
            try await recurrenceRuleLocalStore.save(rule)
        }
        try await fetchLocal()
    }

    func updateRecurrenceRule(_ rule: RecurrenceRule) async throws {
        let updated = try await recurrenceRuleRemoteStore.update(RecurrenceRuleRemote(domain: rule))
        for rule in updated {
            try await recurrenceRuleLocalStore.update(rule)
        }
        try await fetchLocal()
    }

    func deleteRecurrenceRule(_ rule: RecurrenceRule) async throws {
        guard let id = rule.id else { return }
        let deleted = try await recurrenceRuleRemoteStore.delete(RecurrenceRuleRemote(domain: rule))
        for rule in deleted {
            try await recurrenceRuleLocalStore.delete(id: id)
        }
        try await fetchLocal()
    }

    // MARK: - CRUD for EventOverride

    func saveOverride(_ override: EventOverride) async throws {
        let inserted = try await eventOverrideRemoteStore.save(EventOverrideRemote(domain: override))
        for ov in inserted {
            try await eventOverrideLocalStore.save(ov)
        }
        try await fetchLocal()
    }

    func updateOverride(_ override: EventOverride) async throws {
        let updated = try await eventOverrideRemoteStore.update(EventOverrideRemote(domain: override))
        for ov in updated {
            try await eventOverrideLocalStore.update(ov)
        }
        try await fetchLocal()
    }

    func deleteOverride(_ override: EventOverride) async throws {
        guard let id = override.id else { return }
        let deleted = try await eventOverrideRemoteStore.delete(EventOverrideRemote(domain: override))
        for ov in deleted {
            try await eventOverrideLocalStore.delete(id: id)
        }
        try await fetchLocal()
    }

    // MARK: - Batch Delete & Sync

    func deleteAllEvents(userId: UUID) async throws {
        _ = try await eventRemoteStore.deleteAll(for: userId)
        try await eventLocalStore.deleteAll(for: userId)
        // Optionally delete recurrence rules and overrides for this user as well
        try await fetchLocal()
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

    // MARK: - Query helpers (for view models/UI)

    func allEventDates(in range: ClosedRange<Date>) -> [Date] {
        eventOccurrences.value.map { $0.startDate }
            .filter { range.contains($0) }
            .removingDuplicates()
            .sorted()
    }

    func occurrences(on date: Date) -> [EventOccurrence] {
        eventOccurrences.value.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }

    func containsEvent(on date: Date) -> Bool {
        !occurrences(on: date).isEmpty
    }
}

// Helper to remove duplicates by value
extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
