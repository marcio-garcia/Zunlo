//
//  EventRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation
import MiniSignalEye

final class EventRepository {
    private let eventLocalStore: EventLocalStore
    private let eventRemoteStore: EventRemoteStore
    private let recurrenceRuleLocalStore: RecurrenceRuleLocalStore
    private let recurrenceRuleRemoteStore: RecurrenceRuleRemoteStore
    private let eventOverrideLocalStore: EventOverrideLocalStore
    private let eventOverrideRemoteStore: EventOverrideRemoteStore
    
    private let reminderScheduler: ReminderScheduler<Event>
    private let calendar = Calendar.appDefault
    
    var lastEventAction = Observable<LastEventAction>(.none)
    
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
    
    func fetchOccurrences() async throws -> [EventOccurrence] {
        do {
            let occurrences = try await eventRemoteStore.fetchOccurrences()
            let occ = occurrences.map { EventOccurrence(remote: $0) }
            lastEventAction.value = .fetch(occ)
            return occ
        } catch {
            lastEventAction.value = .error(error)
            throw error
        }
    }
    
    func fetchLocalOcc(for userId: UUID?) async throws -> [EventOccurrence] {
        do {
            let occurrences = try await eventLocalStore.fetchOccurrences(for: userId)
            let occ = occurrences.map { EventOccurrence(remote: $0) }
            lastEventAction.value = .fetch(occ)
            return occ
        } catch {
            lastEventAction.value = .error(error)
            throw error
        }
    }
    
    private func fetchLocalEvents() async throws -> [Event] {
        try await eventLocalStore.fetchAll()
    }
    
    private func fetchLocalRules() async throws -> [RecurrenceRule] {
        try await recurrenceRuleLocalStore.fetchAll()
    }
    
    private func fetchLocalOverrides() async throws -> [EventOverride] {
        try await eventOverrideLocalStore.fetchAll()
    }

    // MARK: - CRUD for Events

    func save(_ event: Event) async throws -> [Event] {
        let savedRemote = try await eventRemoteStore.save(EventRemote(domain: event))
        for remote in savedRemote {
            try await eventLocalStore.save(remote)
            reminderScheduler.scheduleReminders(for: Event(remote: remote))
        }
        lastEventAction.value = .insert
        return savedRemote.compactMap { Event(remote: $0) }
    }

    func update(_ event: Event) async throws -> [Event] {
        let updatedRemote = try await eventRemoteStore.update(EventRemote(domain: event))
        for remote in updatedRemote {
            try await eventLocalStore.update(remote)
            reminderScheduler.cancelReminders(for: Event(remote: remote))
            reminderScheduler.scheduleReminders(for: Event(remote: remote))
        }
        lastEventAction.value = .update
        return updatedRemote.compactMap { Event(remote: $0) }
    }
    
    func splitRecurringEvent(_ occurrence: SplitRecurringEventRemote) async throws {
        let _ = try await eventRemoteStore.splitRecurringEvent(occurrence)
        lastEventAction.value = .update
        try await synchronize()
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
        lastEventAction.value = .delete
    }

    // MARK: - CRUD for RecurrenceRule

    func saveRecurrenceRule(_ rule: RecurrenceRule) async throws {
        let inserted = try await recurrenceRuleRemoteStore.save(RecurrenceRuleRemote(domain: rule))
        for rule in inserted {
            try await recurrenceRuleLocalStore.save(rule)
        }
    }

    func updateRecurrenceRule(_ rule: RecurrenceRule) async throws {
        let updated = try await recurrenceRuleRemoteStore.update(RecurrenceRuleRemote(domain: rule))
        for rule in updated {
            try await recurrenceRuleLocalStore.update(rule)
        }
    }

    func deleteRecurrenceRule(_ rule: RecurrenceRule) async throws {
        let deleted = try await recurrenceRuleRemoteStore.delete(RecurrenceRuleRemote(domain: rule))
        for rule in deleted {
            if let id = rule.id {
                try await recurrenceRuleLocalStore.delete(id: id)
            }
        }
    }

    // MARK: - CRUD for EventOverride

    func saveOverride(_ override: EventOverride) async throws {
        let inserted = try await eventOverrideRemoteStore.save(EventOverrideRemote(domain: override))
        for ov in inserted {
            try await eventOverrideLocalStore.save(ov)
        }
    }

    func updateOverride(_ override: EventOverride) async throws {
        let updated = try await eventOverrideRemoteStore.update(EventOverrideRemote(domain: override))
        for ov in updated {
            try await eventOverrideLocalStore.update(ov)
        }
    }

    func deleteOverride(_ override: EventOverride) async throws {
        let deleted = try await eventOverrideRemoteStore.delete(EventOverrideRemote(domain: override))
        for del in deleted {
            if let id = del.id {
                try await eventOverrideLocalStore.delete(id: id)
            }
        }
    }

    // MARK: - Batch Delete & Sync

    func deleteAllEvents(userId: UUID) async throws {
        _ = try await eventRemoteStore.deleteAll(for: userId)
        try await eventLocalStore.deleteAll(for: userId)
        // Optionally delete recurrence rules and overrides for this user as well
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
    }
}

//extension EventRepository: EventSuggestionEngine {
//
//    /// Compute free windows by subtracting busy intervals (events + scheduled tasks) from the day range.
//    public func freeWindows(on date: Date, minimumMinutes: Int) async -> [TimeWindow] {
//        let day = calendar.dayRange(containing: date)
//        let busy = await busyIntervals(on: date)
//            .map { BusyInterval(start: max($0.start, day.lowerBound), end: min($0.end, day.upperBound)) }
//            .filter { $0.start < $0.end }
//
//        let merged = mergeOverlaps(busy)
//
//        var free: [TimeWindow] = []
//        var cursor = day.lowerBound
//        for b in merged {
//            if b.start > cursor { free.append(TimeWindow(start: cursor, end: b.start)) }
//            cursor = max(cursor, b.end)
//        }
//        if cursor < day.upperBound { free.append(TimeWindow(start: cursor, end: day.upperBound)) }
//
//        let minDur = TimeInterval(minimumMinutes * 60)
//        return free.filter { $0.duration >= minDur }
//    }
//
//    /// Return the next busy interval start after the given time, within the same day.
//    public func nextEventStart(after: Date, on date: Date) async -> Date? {
//        let day = calendar.dayRange(containing: date)
//        return await busyIntervals(on: date)
//            .map { BusyInterval(start: max($0.start, day.lowerBound), end: min($0.end, day.upperBound)) }
//            .filter { $0.start > after }
//            .sorted { $0.start < $1.start }
//            .first?.start
//    }
//
//    /// Count overlaps among today's busy intervals (events + scheduled tasks).
//    public func conflictingItemsCount(on date: Date) async -> Int {
//        let intervals = await busyIntervals(on: date).sorted { $0.start < $1.start }
//        var conflicts = 0
//        var currentEnd: Date? = nil
//        for i in intervals {
//            if let e = currentEnd, i.start < e {
//                conflicts += 1
//                currentEnd = max(e, i.end)
//            } else {
//                currentEnd = i.end
//            }
//        }
//        return conflicts
//    }
//
//    // MARK: - Busy intervals (events)
//
//    private func busyIntervals(on date: Date) async -> [BusyInterval] {
//        let day = calendar.dayRange(containing: date)
//        do {
//            let events = try await eventLocalStore.fetchAll()
//            // TODO: If/when you expand recurrences + overrides, append those instances here.
//            let raw = events
//                .filter {
//                    ($0.endDate ?? day.upperBound) >= day.lowerBound && $0.startDate <= day.upperBound
//                }
//                .map { BusyInterval(start: $0.startDate, end: ($0.endDate ?? day.upperBound)) }
//            return mergeOverlaps(raw)
//        } catch {
//            return []
//        }
//    }
//
//    /// Merge overlapping/adjacent busy intervals.
//    private func mergeOverlaps(_ intervals: [BusyInterval]) -> [BusyInterval] {
//        guard !intervals.isEmpty else { return [] }
//        let sorted = intervals.sorted { $0.start < $1.start }
//        var out: [BusyInterval] = []
//        var cur = sorted[0]
//        for it in sorted.dropFirst() {
//            if it.start <= cur.end {
//                cur = BusyInterval(start: cur.start, end: max(cur.end, it.end))
//            } else { out.append(cur); cur = it }
//        }
//        out.append(cur)
//        return out
//    }
//}
