//
//  EventRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation
import Combine

@MainActor
final class EventRepository: ObservableObject {
    // Flat list of all event instances, ready for UI
    @Published private(set) var eventOccurrences: [EventOccurrence] = []

    // Raw domain entities (may be useful for some advanced features)
    private(set) var events: [Event] = []
    private(set) var recurrenceRules: [RecurrenceRule] = []
    private(set) var eventOverrides: [EventOverride] = []

    // Stores
    private let eventLocalStore: EventLocalStore
    private let eventRemoteStore: EventRemoteStore
    private let recurrenceRuleLocalStore: RecurrenceRuleLocalStore
    private let recurrenceRuleRemoteStore: RecurrenceRuleRemoteStore
    private let eventOverrideLocalStore: EventOverrideLocalStore
    private let eventOverrideRemoteStore: EventOverrideRemoteStore

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

    func fetchAll(in range: ClosedRange<Date>? = nil) async {
        do {
            let eventsLocal = try eventLocalStore.fetchAll()
            let rulesLocal = try recurrenceRuleLocalStore.fetchAll()
            let overridesLocal = try eventOverrideLocalStore.fetchAll()
            self.events = eventsLocal.map { Event(local: $0) }
            self.recurrenceRules = rulesLocal.map { RecurrenceRule(local: $0) }
            self.eventOverrides = overridesLocal.map { EventOverride(local: $0) }
            self.eventOccurrences = try composeOccurrences(in: range)
        } catch {
            self.events = []
            self.recurrenceRules = []
            self.eventOverrides = []
            self.eventOccurrences = []
            print("Failed to fetch all local data: \(error)")
        }
    }

    // MARK: - Compose occurrences for the UI

    func composeOccurrences(in range: ClosedRange<Date>? = nil) throws -> [EventOccurrence] {
        let usedRange = range ?? defaultDateRange()
        return try EventOccurrenceService.generate(
            events: self.events,
            rules: self.recurrenceRules,
            overrides: self.eventOverrides,
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
            try eventLocalStore.save(EventLocal(remote: event))
        }
        await fetchAll()
        return inserted.compactMap { Event(remote: $0) }
    }

    func update(_ event: Event) async throws {
        let updated = try await eventRemoteStore.update(EventRemote(domain: event))
        for event in updated {
            try eventLocalStore.update(EventLocal(remote: event))
        }
        await fetchAll()
    }

    func delete(_ event: Event) async throws {
        let deleted = try await eventRemoteStore.delete(EventRemote(domain: event))
        for event in deleted {
            try eventLocalStore.delete(EventLocal(remote: event))
        }
        await fetchAll()
    }

    // MARK: - CRUD for RecurrenceRule

    func saveRecurrenceRule(_ rule: RecurrenceRule) async throws {
        let inserted = try await recurrenceRuleRemoteStore.save(RecurrenceRuleRemote(domain: rule))
        for rule in inserted {
            try recurrenceRuleLocalStore.save(RecurrenceRuleLocal(remote: rule))
        }
        await fetchAll()
    }

    func updateRecurrenceRule(_ rule: RecurrenceRule) async throws {
        let updated = try await recurrenceRuleRemoteStore.update(RecurrenceRuleRemote(domain: rule))
        for rule in updated {
            try recurrenceRuleLocalStore.update(RecurrenceRuleLocal(remote: rule))
        }
        await fetchAll()
    }

    func deleteRecurrenceRule(_ rule: RecurrenceRule) async throws {
        let deleted = try await recurrenceRuleRemoteStore.delete(RecurrenceRuleRemote(domain: rule))
        for rule in deleted {
            try recurrenceRuleLocalStore.delete(RecurrenceRuleLocal(remote: rule))
        }
        await fetchAll()
    }

    // MARK: - CRUD for EventOverride

    func saveOverride(_ override: EventOverride) async throws {
        let inserted = try await eventOverrideRemoteStore.save(EventOverrideRemote(domain: override))
        for ov in inserted {
            try eventOverrideLocalStore.save(EventOverrideLocal(remote: ov))
        }
        await fetchAll()
    }

    func updateOverride(_ override: EventOverride) async throws {
        let updated = try await eventOverrideRemoteStore.update(EventOverrideRemote(domain: override))
        for ov in updated {
            try eventOverrideLocalStore.update(EventOverrideLocal(remote: ov))
        }
        await fetchAll()
    }

    func deleteOverride(_ override: EventOverride) async throws {
        let deleted = try await eventOverrideRemoteStore.delete(EventOverrideRemote(domain: override))
        for ov in deleted {
            try eventOverrideLocalStore.delete(EventOverrideLocal(remote: ov))
        }
        await fetchAll()
    }

    // MARK: - Batch Delete & Sync

    func deleteAllEvents(userId: UUID) async throws {
        _ = try await eventRemoteStore.deleteAll(for: userId)
        try eventLocalStore.deleteAll(for: userId)
        // Optionally delete recurrence rules and overrides for this user as well
        await fetchAll()
    }

    /// Fetch everything from remote and overwrite local cache
    func synchronize() async throws {
        let remoteEvents = try await eventRemoteStore.fetchAll()
        let remoteRules = try await recurrenceRuleRemoteStore.fetchAll()
        let remoteOverrides = try await eventOverrideRemoteStore.fetchAll()

        try eventLocalStore.deleteAll()
        try recurrenceRuleLocalStore.deleteAll()
        try eventOverrideLocalStore.deleteAll()

        for e in remoteEvents { try eventLocalStore.save(EventLocal(remote: e)) }
        for r in remoteRules { try recurrenceRuleLocalStore.save(RecurrenceRuleLocal(remote: r)) }
        for o in remoteOverrides { try eventOverrideLocalStore.save(EventOverrideLocal(remote: o)) }

        await fetchAll()
    }

    // MARK: - Query helpers (for view models/UI)

    func allEventDates(in range: ClosedRange<Date>) -> [Date] {
        eventOccurrences.map { $0.startDate }
            .filter { range.contains($0) }
            .removingDuplicates()
            .sorted()
    }

    func occurrences(on date: Date) -> [EventOccurrence] {
        eventOccurrences.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
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
