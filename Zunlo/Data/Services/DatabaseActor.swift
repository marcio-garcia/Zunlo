//
//  DatabaseActor.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import RealmSwift

public actor DatabaseActor {
    private let config: Realm.Configuration
    // Keeps the in-memory realm alive for the test's lifetime
    private var anchorRealm: Realm?
    
    /// Use `keepAliveAnchor: true` when using in-memory configs in tests.
    public init(
        config: Realm.Configuration = .defaultConfiguration,
        keepAliveAnchor: Bool = false
    ) {
        self.config = config
        if keepAliveAnchor, config.inMemoryIdentifier != nil {
            // It's okay to use try! in tests; if this fails you want the test to crash loudly.
            self.anchorRealm = try? Realm(configuration: config)
        }
    }
    
    // Open a short-lived Realm for an operation on the actor's executor
    @inline(__always)
    private func openRealm() throws -> Realm {
        try Realm(configuration: config)
    }

    // --- Test utilities ---

    /// Remove all objects. Handy in setUp/tearDown between test phases.
    func resetAll() throws {
        let realm = try openRealm()
        try realm.write { realm.deleteAll() }
    }

    /// Optional: force compaction (not required for in-memory, but fine to keep)
//    func compactOnLaunch() throws {
//        _ = try Realm.performMigration(for: config)
//        _ = try Realm.compactRealm(configuration: config)
//    }
    
    // ===== Events =====

    func readDirtyEvents() throws -> ([EventRemote], [UUID]) {
        let realm = try Realm()
        let dirty = Array(realm.objects(EventLocal.self).where { $0.needsSync == true })
        return (dirty.map(EventRemote.init(local:)), dirty.map(\.id))
    }

    func markEventsClean(_ ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let realm = try Realm()
        let objs = realm.objects(EventLocal.self).where { $0.id.in(ids) } // Query DSL
        try realm.write { for obj in objs { obj.needsSync = false } }
    }

    func applyRemoteEvents(_ rows: [EventRemote]) throws {
        let realm = try Realm()
        try realm.write {
            for r in rows {
//                if let existing = realm.object(ofType: EventLocal.self, forPrimaryKey: r.id),
//                   existing.needsSync == true { continue } // v1 trade-off
                let obj = realm.object(ofType: EventLocal.self, forPrimaryKey: r.id)
                ?? EventLocal(value: ["id": r.id])
                obj.getUpdateFields(r)
                realm.add(obj, update: .modified)
            }
        }
    }

    // ===== RecurrenceRules =====

    func readDirtyRecurrenceRules() throws -> ([RecurrenceRuleRemote], [UUID]) {
        let realm = try Realm()
        let dirty = Array(realm.objects(RecurrenceRuleLocal.self).where { $0.needsSync == true })
        return (dirty.map(RecurrenceRuleRemote.init(local:)), dirty.map(\.id))
    }

    func markRecurrenceRulesClean(_ ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let realm = try Realm()
        let objs = realm.objects(RecurrenceRuleLocal.self).where { $0.id.in(ids) }
        try realm.write { for obj in objs { obj.needsSync = false } }
    }

    func applyRemoteRecurrenceRules(_ rows: [RecurrenceRuleRemote]) throws {
        let realm = try Realm()
        try realm.write {
            for r in rows {
//                if let existing = realm.object(ofType: RecurrenceRuleLocal.self, forPrimaryKey: r.id),
//                   existing.needsSync == true { continue }
                let obj = realm.object(ofType: RecurrenceRuleLocal.self, forPrimaryKey: r.id)
                    ?? RecurrenceRuleLocal(remote: r)
                obj.getUpdateFields(r)
                realm.add(obj, update: .modified)
            }
        }
    }

    // ===== EventOverrides =====

    func readDirtyEventOverrides() throws -> ([EventOverrideRemote], [UUID]) {
        let realm = try Realm()
        let dirty = Array(realm.objects(EventOverrideLocal.self).where { $0.needsSync == true })
        return (dirty.map(EventOverrideRemote.init(local:)), dirty.map(\.id))
    }

    func markEventOverridesClean(_ ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let realm = try Realm()
        let objs = realm.objects(EventOverrideLocal.self).where { $0.id.in(ids) }
        try realm.write { for obj in objs { obj.needsSync = false } }
    }

    func applyRemoteEventOverrides(_ rows: [EventOverrideRemote]) throws {
        let realm = try Realm()
        try realm.write {
            for r in rows {
//                if let existing = realm.object(ofType: EventOverrideLocal.self, forPrimaryKey: id),
//                   existing.needsSync == true { continue }
                let obj = realm.object(ofType: EventOverrideLocal.self, forPrimaryKey: r.id)
                    ?? EventOverrideLocal(remote: r)
                obj.getUpdateFields(r)
                realm.add(obj, update: .modified)
            }
        }
    }
    
    // --------------------------------------------------------
    // MARK: Events
    // --------------------------------------------------------

    func fetchEvent(id: UUID) throws -> EventLocal? {
        let realm = try openRealm()
        guard let obj = realm.object(ofType: EventLocal.self, forPrimaryKey: id) else {
            return nil
        }
        return obj
    }
    
    // Keep NSPredicate here because the filter is complex (ANY tags, ranges, etc.)
    func fetchEvents(filteredBy filter: EventFilter?) throws -> [EventLocal] {
        let realm = try openRealm()
        var predicates: [NSPredicate] = []

//        if let tags = filter?.tags, !tags.isEmpty {
//            predicates.append(NSPredicate(format: "ANY tags IN %@", tags))
//        }
        if let userId = filter?.userId {
            predicates.append(NSPredicate(format: "userId == %@", userId as CVarArg))
        }
//        if let priority = filter?.priority {
//            predicates.append(NSPredicate(format: "priority == %@", priority.rawValue))
//        }
//        if let isCompleted = filter?.isCompleted {
//            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: isCompleted)))
//        }
        if let range = filter?.startDateRange {
            predicates.append(NSPredicate(format: "startDate >= %@ AND startDate <= %@", range.lowerBound as NSDate, range.upperBound as NSDate))
        }
        if let range = filter?.endDateRange {
            predicates.append(NSPredicate(format: "endDate >= %@ AND endDate <= %@", range.lowerBound as NSDate, range.upperBound as NSDate))
        }

        var query = realm.objects(EventLocal.self)
        if !predicates.isEmpty {
            let compound = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            query = query.filter(compound)
        }

        let sorted = query.sorted(by: [
            SortDescriptor(keyPath: "startDate", ascending: true)
        ])
        return sorted.map { $0 }
    }
    
    func fetchAllEventsSorted() throws -> [EventLocal] {
        let realm = try openRealm()
        let results = realm.objects(EventLocal.self)
            .sorted(byKeyPath: "startDate", ascending: true)
        return results.map { $0 }
    }

    func upsertEvent(from remote: EventRemote, userId: UUID?) throws {
        let realm = try openRealm()
        try realm.write {
            let obj = realm.object(ofType: EventLocal.self, forPrimaryKey: remote.id) ?? EventLocal(remote: remote)
            obj.getUpdateFields(remote)
            if obj.userId == nil { obj.userId = userId } // keep local queryability
            obj.deletedAt = remote.deleted_at
            obj.needsSync = false
            realm.add(obj, update: .modified)
        }
    }

    func upsertEvent(from local: EventLocal, userId: UUID?) throws {
        let realm = try openRealm()
        try realm.write {
            let obj = realm.object(ofType: EventLocal.self, forPrimaryKey: local.id) ?? local
            obj.getUpdateFields(local)
            if obj.userId == nil { obj.userId = userId }
            obj.updatedAt = Date()         // local stamp (server will overwrite)
            obj.needsSync = true
            realm.add(obj, update: .modified)
        }
    }
    
    func upsertEvent(local: EventLocal, rule: RecurrenceRule, userId: UUID?) throws {
        let realm = try openRealm()
        realm.beginWrite()
        do {
            let localEvent = realm.object(ofType: EventLocal.self, forPrimaryKey: local.id) ?? local
            localEvent.getUpdateFields(local)
            if localEvent.userId == nil { localEvent.userId = userId }
            localEvent.updatedAt = Date()         // local stamp (server will overwrite)
            localEvent.needsSync = true
            realm.add(localEvent, update: .modified)
            
            let localRule = realm.object(ofType: RecurrenceRuleLocal.self, forPrimaryKey: rule.id)
                ?? RecurrenceRuleLocal(domain: rule)
            localRule.getUpdateFields(rule)
            localRule.updatedAt = Date()
            localRule.needsSync = true
            realm.add(localRule, update: .modified)
            
            try realm.commitWrite()
        } catch {
            realm.cancelWrite()
        }
    }

    func deleteAllEvents() throws {
        let realm = try openRealm()
        try realm.write {
            realm.delete(realm.objects(EventLocal.self))
        }
    }

    func deleteAllEvents(for userId: UUID) throws {
        let realm = try openRealm()
        let objs = realm.objects(EventLocal.self).where { $0.userId == userId }
        try realm.write { realm.delete(objs) }
    }

    // Aggregated fetch mirroring your remote payload shape
    func fetchOccurrences(userId: UUID) throws -> [EventOccurrenceResponse] {
        let realm = try openRealm()

        // 1) Events for user, ordered deterministically
        var events = realm.objects(EventLocal.self).where { $0.userId == userId }
        events = events
            .sorted(byKeyPath: "startDate", ascending: true)
            .sorted(byKeyPath: "id", ascending: true)

        let eventLocals = Array(events)
        guard !eventLocals.isEmpty else { return [] }

        let eventIds = eventLocals.map(\.id)

        // 2) Bulk children
        let overrides = Array(
            realm.objects(EventOverrideLocal.self)
                 .where { $0.eventId.in(eventIds) }
                 .sorted(byKeyPath: "id", ascending: true)
        )
        let rules = Array(
            realm.objects(RecurrenceRuleLocal.self)
                 .where { $0.eventId.in(eventIds) }
                 .sorted(byKeyPath: "id", ascending: true)
        )

        // 3) Group
        let ovsByEvent = Dictionary(grouping: overrides, by: \.eventId)
        let rrsByEvent = Dictionary(grouping: rules,     by: \.eventId)

        // 4) Build result
        return eventLocals.map { e in
            EventOccurrenceResponse(local: e,
                                    overrides: ovsByEvent[e.id] ?? [],
                                    rules: rrsByEvent[e.id] ?? [])
        }
    }

    // --------------------------------------------------------
    // MARK: Event Overrides
    // --------------------------------------------------------

    func fetchAllEventOverrides() throws -> [EventOverride] {
        let realm = try openRealm()
        return realm.objects(EventOverrideLocal.self).map { EventOverride(local: $0) }
    }

    func fetchOverrides(for eventId: UUID) throws -> [EventOverride] {
        let realm = try openRealm()
        let results = realm.objects(EventOverrideLocal.self).where { $0.eventId == eventId }
        return results.map { EventOverride(local: $0) }
    }

    func upsertOverride(from remote: EventOverrideRemote) throws {
        let realm = try openRealm()
        try realm.write {
            let obj = realm.object(ofType: EventOverrideLocal.self, forPrimaryKey: remote.id)
                ?? EventOverrideLocal(remote: remote)
            obj.getUpdateFields(remote)
            realm.add(obj, update: .modified)
        }
    }

    func upsertOverride(from domain: EventOverride) throws {
        let realm = try openRealm()
        try realm.write {
            let obj = realm.object(ofType: EventOverrideLocal.self, forPrimaryKey: domain.id)
                ?? EventOverrideLocal(domain: domain)
            obj.getUpdateFields(domain)
            obj.updatedAt = Date()
            obj.needsSync = true
            realm.add(obj, update: .modified)
        }
    }

    func softDeleteOverride(id: UUID) throws {
        let realm = try openRealm()
        try realm.write {
            guard let existing = realm.object(ofType: EventOverrideLocal.self, forPrimaryKey: id) else { return }
            existing.deletedAt = Date()
            existing.updatedAt = Date()
            existing.needsSync = true
        }
    }

    func deleteAllOverrides() throws {
        let realm = try openRealm()
        try realm.write {
            realm.delete(realm.objects(EventOverrideLocal.self))
        }
    }

    // --------------------------------------------------------
    // MARK: Recurrence Rules
    // --------------------------------------------------------

    func fetchAllRecurrenceRules() throws -> [RecurrenceRule] {
        let realm = try openRealm()
        return realm.objects(RecurrenceRuleLocal.self).map { RecurrenceRule(local: $0) }
    }

    func fetchRecurrenceRules(for eventId: UUID) throws -> [RecurrenceRule] {
        let realm = try openRealm()
        let results = realm.objects(RecurrenceRuleLocal.self).where { $0.eventId == eventId }
        return results.map { RecurrenceRule(local: $0) }
    }

    func upsertRecurrenceRule(from remote: RecurrenceRuleRemote) throws {
        let realm = try openRealm()
        try realm.write {
            let obj = realm.object(ofType: RecurrenceRuleLocal.self, forPrimaryKey: remote.id)
                ?? RecurrenceRuleLocal(remote: remote)
            obj.getUpdateFields(remote)
            realm.add(obj, update: .modified)
        }
    }

    func upsertRecurrenceRule(from domain: RecurrenceRule) throws {
        let realm = try openRealm()
        try realm.write {
            let obj = realm.object(ofType: RecurrenceRuleLocal.self, forPrimaryKey: domain.id)
                ?? RecurrenceRuleLocal(domain: domain)
            obj.getUpdateFields(domain)
            obj.updatedAt = Date()
            obj.needsSync = true
            realm.add(obj, update: .modified)
        }
    }

    func softDeleteRecurrenceRule(id: UUID) throws {
        let realm = try openRealm()
        try realm.write {
            guard let obj = realm.object(ofType: RecurrenceRuleLocal.self, forPrimaryKey: id) else { return }
            obj.deletedAt = Date()
            obj.updatedAt = Date()
            obj.needsSync = true
        }
    }

    func deleteAllRecurrenceRules() throws {
        let realm = try openRealm()
        try realm.write {
            realm.delete(realm.objects(RecurrenceRuleLocal.self))
        }
    }

    // --------------------------------------------------------
    // MARK: User Tasks
    // --------------------------------------------------------

    func readDirtyUserTasks() throws -> ([UserTaskRemote], [UUID]) {
        let realm = try openRealm()
        let dirty = Array(realm.objects(UserTaskLocal.self).where { $0.needsSync == true })
        return (dirty.map { UserTaskRemote(domain: $0.toDomain()) }, dirty.map(\.id))
    }

    func markUserTasksClean(_ ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let realm = try openRealm()
        let objs = realm.objects(UserTaskLocal.self).where { $0.id.in(ids) }
        try realm.write { for obj in objs { obj.needsSync = false } }
    }

    func applyRemoteUserTasks(_ rows: [UserTaskRemote]) throws {
        let realm = try openRealm()
        try realm.write {
            for r in rows {
                let id = r.id
//                if let existing = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: id),
//                   existing.needsSync == true { continue } // v1 trade-off: don't stomp local dirty
                let obj = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: id) ?? UserTaskLocal(remote: r)
                obj.getUpdateFields(remote: r)
                realm.add(obj, update: .modified)
            }
        }
    }

    // Optional: local upsert entry points you already call elsewhere
    func upsertUserTask(from remote: UserTaskRemote) throws {
        let realm = try openRealm()
        try realm.write {
            let obj = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: remote.id) ?? UserTaskLocal(remote: remote)
            obj.getUpdateFields(remote: remote)
            realm.add(obj, update: .modified)
        }
    }

    func upsertUserTask(from domain: UserTask) throws {
        let realm = try openRealm()
        try realm.write {
            let obj = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: domain.id) ?? UserTaskLocal(domain: domain)
            obj.getUpdateFields(domain: domain)
            realm.add(obj, update: .modified)
        }
    }
    
    func deleteUserTask(id: UUID) throws {
        let realm = try openRealm()
        try realm.write {
            if let existing = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: id) {
                existing.deletedAt = Date()
                existing.needsSync = true
            }
        }
    }

    func fetchTask(id: UUID) throws -> UserTaskLocal? {
        let realm = try openRealm()
        guard let obj = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: id) else {
            return nil
        }
        return obj
    }
    
    func fetchAllUserTasks() throws -> [UserTask] {
        let realm = try openRealm()
        let locals = Array(
            realm.objects(UserTaskLocal.self).sorted(by: [
                SortDescriptor(keyPath: "priority", ascending: false),
                SortDescriptor(keyPath: "dueDate", ascending: true)
            ])
        )
        return locals.map { $0.toDomain() }
    }

    // Keep NSPredicate here because the filter is complex (ANY tags, ranges, etc.)
    func fetchUserTasks(filteredBy filter: TaskFilter?) throws -> [UserTask] {
        let realm = try openRealm()
        var predicates: [NSPredicate] = []

        if let tags = filter?.tags, !tags.isEmpty {
            predicates.append(NSPredicate(format: "ANY tags IN %@", tags))
        }
        if let userId = filter?.userId {
            predicates.append(NSPredicate(format: "userId == %@", userId as CVarArg))
        }
        if let priority = filter?.priority {
            predicates.append(NSPredicate(format: "priority == %@", NSNumber(value: priority.rawValue)))
        }
        if let isCompleted = filter?.isCompleted {
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: isCompleted)))
        }
        if let range = filter?.dueDateRange {
            predicates.append(NSPredicate(format: "dueDate >= %@ AND dueDate <= %@", range.lowerBound as NSDate, range.upperBound as NSDate))
        }

        var query = realm.objects(UserTaskLocal.self)
        if !predicates.isEmpty {
            let compound = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            query = query.filter(compound)
        }

        let sorted = query.sorted(by: [
            SortDescriptor(keyPath: "priority", ascending: false),
            SortDescriptor(keyPath: "dueDate", ascending: true)
        ])
        return sorted.map { $0.toDomain() }
    }

    func fetchAllUniqueTaskTags() throws -> [String] {
        let realm = try openRealm()
        let tasks = realm.objects(UserTaskLocal.self)
        let allTags = tasks.flatMap { $0.tags }
        let unique = Set(allTags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        return Array(unique).sorted()
    }
}

extension DatabaseActor {

    enum SplitSeriesError: Error, LocalizedError {
        case eventNotFound
        case unauthorized
        case invalidSplitDate
        var errorDescription: String? {
            switch self {
            case .eventNotFound:   return "Original event not found."
            case .unauthorized:    return "Event not found or unauthorized."
            case .invalidSplitDate:return "Could not compute cutoff date from splitDate."
            }
        }
    }
    
    /// Split a recurring series at `splitDate`,
    /// moving occurrences at/after `splitDate` to a brand-new event.
    ///
    /// Steps performed by the split:
    /// - validates ownership,
    /// - creates a new event (client-owned id),
    /// - clones the recurrence rule (if any) to the new event,
    /// - shortens the original rule’s until to (splitDate - 1 day) (only if NULL or greater),
    /// - repoints overrides with occurrenceDate >= splitDate to the new event,
    /// - stamps updatedAt = Date() and marks locals as needsSync = true so your next push sends all changes.
    ///
    /// - Parameters:
    ///   - originalEventId: series to split
    ///   - splitDate: first occurrence that should belong to the *new* series
    ///   - newEvent: the new event prototype (title/desc/start/end/etc). If `id` is nil, a new UUID is generated.
    ///   - userId: the current authenticated user (used for ownership check and to set `userId` on the new event)
    /// - Returns: the new event's UUID
    func splitRecurringEventFrom(
        originalEventId: UUID,
        splitDate: Date,
        newEvent: EventLocal,
        userId: UUID
    ) throws -> UUID {
        let realm = try openRealm()

        // Validate ownership (read-only)
        guard let original = realm.object(ofType: EventLocal.self, forPrimaryKey: originalEventId) else {
            throw SplitSeriesError.eventNotFound
        }
        guard original.userId == userId else {
            throw SplitSeriesError.unauthorized
        }

        let newEventId = newEvent.id
        
        let now = Date()
        guard let cutoff = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: splitDate) else {
            throw SplitSeriesError.invalidSplitDate
        }

        realm.beginWrite()
        do {
            // 1) Insert new event, mark dirty
            let newLocal = newEvent
            newLocal.deletedAt = nil
            newLocal.needsSync = true
            realm.add(newLocal, update: .modified)

            // 2) Clone ONE recurrence rule (LIMIT 1), mark dirty
            if let origRule = realm.objects(RecurrenceRuleLocal.self)
                .where({ $0.eventId == originalEventId })
                .first
            {
                let cloned = RecurrenceRuleLocal(
                    id: UUID(),
                    eventId: newEventId,
                    freq: origRule.freq,
                    interval: origRule.interval,
                    byWeekday: origRule.byWeekdayArray,
                    byMonthday: origRule.byMonthdayArray,
                    byMonth: origRule.byMonthArray,
                    until: origRule.until,
                    count: origRule.count,
                    createdAt: now,
                    updatedAt: now,
                    deletedAt: nil,
                    needsSync: true,
                    version: origRule.version
                )
                realm.add(cloned, update: .modified)
            }

            // 3) Shorten original rule(s) until → cutoff, mark dirty
            let origRules = realm.objects(RecurrenceRuleLocal.self)
                .where { $0.eventId == originalEventId }
            for rule in origRules {
                if rule.until == nil || rule.until! > cutoff {
                    rule.until = cutoff
                    rule.updatedAt = now
                    rule.needsSync = true
                }
            }

            // 4) Repoint overrides at/after splitDate to the new event, mark dirty
            let toMove = realm.objects(EventOverrideLocal.self)
                .where { $0.eventId == originalEventId && $0.occurrenceDate >= splitDate }
            for ov in toMove {
                ov.eventId = newEventId
                ov.updatedAt = now
                ov.needsSync = true
                ov.deletedAt = nil
            }

            try realm.commitWrite()
        } catch {
            realm.cancelWrite()
            throw error
        }

        return newEventId
    }
    
    
    enum UndoSplitError: Error, LocalizedError {
        case originalNotFound
        case newEventNotFound
        case unauthorized
        var errorDescription: String? {
            switch self {
            case .originalNotFound: return "Original event not found."
            case .newEventNotFound: return "New event not found."
            case .unauthorized:     return "Events not found or unauthorized."
            }
        }
    }

    /// Merge a previously split series back into the original.
    ///
    /// Steps performed by the merge:
    /// - Validates both events belong to the same user.
    /// - Moves all overrides from the new event back to the original (needsSync = true).
    /// - Restores the original rule’s until from the new rule’s until (which was the pre-split value, since we cloned it).
    /// - If the cloned until is nil, original becomes nil (open-ended).
    /// - If both non-nil, original gets the max to avoid shrinking the window by mistake.
    /// - Soft-deletes the new event’s recurrence rule(s) (sets deletedAt, needsSync).
    /// - Soft-deletes the new event itself (sets deletedAt, needsSync).
    ///
    /// - Parameters:
    ///   - originalEventId: ID of the original recurring event.
    ///   - newEventId: ID of the event created by the split.
    ///   - userId: Current user (ownership check).
    func undoSplitRecurringEvent(
        originalEventId: UUID,
        newEventId: UUID,
        userId: UUID
    ) throws {
        let realm = try openRealm()

        // Validate ownership (read-only)
        guard let original = realm.object(ofType: EventLocal.self, forPrimaryKey: originalEventId) else {
            throw UndoSplitError.originalNotFound
        }
        guard let newEvent = realm.object(ofType: EventLocal.self, forPrimaryKey: newEventId) else {
            throw UndoSplitError.newEventNotFound
        }
        guard original.userId == userId, newEvent.userId == userId else {
            throw UndoSplitError.unauthorized
        }

        let now = Date()

        // Find the cloned rule on the new event (the "pre-split" until)
        let newRule = realm.objects(RecurrenceRuleLocal.self)
            .where { $0.eventId == newEventId }
            .first
        let newUntil = newRule?.until

        realm.beginWrite()
        do {
            // 1) Move overrides back to the original, mark dirty
            let movedOverrides = realm.objects(EventOverrideLocal.self)
                .where { $0.eventId == newEventId }
            for ov in movedOverrides {
                ov.eventId = originalEventId
                ov.updatedAt = now
                ov.needsSync = true
                // keep deletedAt as-is (should be nil here)
            }
            
            // 2) Restore original rule 'until' from new rule
            let origRules = realm.objects(RecurrenceRuleLocal.self)
                .where { $0.eventId == originalEventId }
            for rule in origRules {
                switch (rule.until, newUntil) {
                case (nil, _):
                    rule.until = newUntil
                    rule.updatedAt = now
                    rule.needsSync = true
                case (let ru?, let nu):
                    // Expand but never shrink
                    if nu == nil || (nu! > ru) {
                        rule.until = nu
                        rule.updatedAt = now
                        rule.needsSync = true
                    }
                }
            }
            
            // 3) Soft-delete new event's recurrence rule(s)
            let newRulesAll = realm.objects(RecurrenceRuleLocal.self)
                .where { $0.eventId == newEventId }
            for r in newRulesAll {
                r.deletedAt = now
                r.updatedAt = now
                r.needsSync = true
            }
            
            // 4) Soft-delete the new event row
            newEvent.deletedAt = now
            newEvent.updatedAt = now
            newEvent.needsSync = true
            
            try realm.commitWrite()
        } catch {
            realm.cancelWrite()
            throw error
        }
    }
}

extension DatabaseActor {

    // Mark ONE event dirty; optionally cascade to its rule(s) & overrides.
    func markEventDirty(_ eventId: UUID, cascade: Bool = true, touch: Bool = true) throws {
        let realm = try openRealm()
        let now = Date()

        try realm.write {
            if let ev = realm.object(ofType: EventLocal.self, forPrimaryKey: eventId) {
                ev.needsSync = true
                if touch { ev.updatedAt = now }
            }

            guard cascade else { return }

            // Recurrence rule(s) for this event
            let rules = realm.objects(RecurrenceRuleLocal.self)
                .where { $0.eventId == eventId }
            for r in rules {
                r.needsSync = true
                if touch { r.updatedAt = now }
            }

            // Overrides for this event
            let ovs = realm.objects(EventOverrideLocal.self)
                .where { $0.eventId == eventId }
            for o in ovs {
                o.needsSync = true
                if touch { o.updatedAt = now }
            }
        }
    }

    // Mark MANY events dirty in one transaction.
    func markEventsDirty(_ ids: [UUID], cascade: Bool = true, touch: Bool = true) throws {
        guard !ids.isEmpty else { return }
        let realm = try openRealm()
        let now = Date()

        try realm.write {
            // Events
            let evs = realm.objects(EventLocal.self).where { $0.id.in(ids) }
            for ev in evs {
                ev.needsSync = true
                if touch { ev.updatedAt = now }
            }

            guard cascade else { return }

            // Rules
            let rules = realm.objects(RecurrenceRuleLocal.self).where { $0.eventId.in(ids) }
            for r in rules {
                r.needsSync = true
                if touch { r.updatedAt = now }
            }

            // Overrides
            let ovs = realm.objects(EventOverrideLocal.self).where { $0.eventId.in(ids) }
            for o in ovs {
                o.needsSync = true
                if touch { o.updatedAt = now }
            }
        }
    }

    // Convenience: mark ALL events (optionally for a specific user) dirty.
    func markAllEventsDirty(for userId: UUID? = nil, cascade: Bool = true, touch: Bool = true) throws {
        let realm = try openRealm()
        var evs = realm.objects(EventLocal.self)
        if let uid = userId {
            evs = evs.where { $0.userId == uid }
        }
        try markEventsDirty(Array(evs.map(\.id)), cascade: cascade, touch: touch)
    }

    // Optional: if you want to force a re-PULL from server too, rewind the events cursor.
    func rewindEventsCursor(to date: Date? = nil, id: UUID? = nil) {
        let tsKey = "events.cursor.ts"
        let idKey = "events.cursor.id"
        if let d = date {
            UserDefaults.standard.set(d.rfc3339MicroString(), forKey: tsKey)
        } else {
            UserDefaults.standard.set("1970-01-01T00:00:00.000000Z", forKey: tsKey)
        }
        if let id { UserDefaults.standard.set(id.uuidString, forKey: idKey) }
        else { UserDefaults.standard.removeObject(forKey: idKey) }
    }
}

extension DatabaseActor {
    enum EventDeleteError: Error {
        case eventNotFound
        case unauthorized
    }

    /// Soft-delete an event and all of its children (rules, overrides).
    /// Marks every changed row `needsSync = true` so push will upsert tombstones.
    func softDeleteEvent(id: UUID, userId: UUID?) throws {
        let realm = try openRealm()

        guard let existing = realm.object(ofType: EventLocal.self, forPrimaryKey: id) else {
            throw EventDeleteError.eventNotFound
        }
        guard existing.userId == userId else {
            throw EventDeleteError.unauthorized
        }

        let now = Date()

        realm.beginWrite()
        do {
            // Event
            existing.deletedAt = now
            existing.updatedAt = now
            existing.needsSync = true

            // Overrides for this event
            let overrides = realm.objects(EventOverrideLocal.self)
                .where { $0.eventId == id && $0.deletedAt == nil }
            for ov in overrides {
                ov.deletedAt = now
                ov.updatedAt = now
                ov.needsSync = true
            }

            // Recurrence rules for this event
            let rules = realm.objects(RecurrenceRuleLocal.self)
                .where { $0.eventId == id && $0.deletedAt == nil }
            for rule in rules {
                rule.deletedAt = now
                rule.updatedAt = now
                rule.needsSync = true
            }

            try realm.commitWrite()
        } catch {
            realm.cancelWrite()
            throw error
        }
    }
    
    func undeleteEvent(id: UUID, userId: UUID) throws {
        let realm = try openRealm()
        guard let ev = realm.object(ofType: EventLocal.self, forPrimaryKey: id),
              ev.userId == userId else { throw EventDeleteError.eventNotFound }
        let now = Date()
        try realm.write {
            ev.deletedAt = nil; ev.updatedAt = now; ev.needsSync = true
            let rules = realm.objects(RecurrenceRuleLocal.self).where { $0.eventId == id }
            for r in rules { r.deletedAt = nil; r.updatedAt = now; r.needsSync = true }
            let ovs = realm.objects(EventOverrideLocal.self).where { $0.eventId == id }
            for o in ovs { o.deletedAt = nil; o.updatedAt = now; o.needsSync = true }
        }
    }
}

extension DatabaseActor {
    public enum ChatDBError: Error, LocalizedError {
        case messageNotFound(UUID)
        case conversationNotFound(UUID)
        public var errorDescription: String? {
            switch self {
            case .messageNotFound(let id): return "Chat message not found: \(id.uuidString)"
            case .conversationNotFound(let id): return "Conversation not found: \(id.uuidString)"
            }
        }
    }
}

// MARK: - Conversation helpers (Option B)

extension DatabaseActor {
    /// Ensure the **single** default conversation exists and return its id.
    /// If a non-archived "general" conversation exists, returns it; otherwise creates a new one.
    public func ensureDefaultConversation() throws -> UUID {
        let realm = try openRealm()
        if let existing = realm.objects(ConversationObject.self)
            .where({ $0.archived == false && $0.kindRaw == "general" })
            .sorted(byKeyPath: "createdAt", ascending: true)
            .first {
            return existing.id
        }
        let convo = ConversationObject()
        convo.id = UUID()
        convo.title = "Chat"
        convo.kindRaw = "general"
        convo.createdAt = Date()
        convo.updatedAt = Date()
        try realm.write { realm.add(convo, update: .modified) }
        return convo.id
    }

    /// Make sure a conversation with the given id exists (used when writing messages).
    /// If it's missing (e.g., restored from sync), it will be created with a sane default.
    public func ensureConversationExists(id: UUID, title: String? = "Chat", kindRaw: String = "general") throws {
        let realm = try openRealm()
        if realm.object(ofType: ConversationObject.self, forPrimaryKey: id) != nil { return }
        let convo = ConversationObject()
        convo.id = id
        convo.title = title
        convo.kindRaw = kindRaw
        convo.createdAt = Date()
        convo.updatedAt = Date()
        try realm.write { realm.add(convo, update: .modified) }
    }

    /// Update title or archive flag for the single conversation.
    public func updateDefaultConversation(title: String? = nil, archived: Bool? = nil, draftInput: String? = nil) throws {
        let realm = try openRealm()
        guard let convo = realm.objects(ConversationObject.self)
            .where({ $0.kindRaw == "general" })
            .first else { return }
        try realm.write {
            if let title { convo.title = title }
            if let archived { convo.archived = archived }
            if let draftInput { convo.draftInput = draftInput }
            convo.updatedAt = Date()
        }
    }

    /// Fetch the single conversation object (useful for tests/UI).
    public func fetchDefaultConversation() throws -> ConversationObject? {
        let realm = try openRealm()
        return realm.objects(ConversationObject.self)
            .where({ $0.kindRaw == "general" && $0.archived == false })
            .first
    }
}

// MARK: - Chat CRUD + conversation "touch" integration

extension DatabaseActor {
    /// Fetch messages for the (single) conversation, ascending by time. Optional limit.
    public func fetchChatMessages(conversationId: UUID, limit: Int? = nil) throws -> [ChatMessage] {
        let realm = try openRealm()
        let results = realm.objects(ChatMessageLocal.self)
            .where { $0.conversationId == conversationId }
            .sorted(byKeyPath: "createdAt", ascending: true)
        if let limit, limit > 0, results.count > limit {
            let slice = results.suffix(limit)
            return slice.map { ChatMessage(from: $0) }
        } else {
            return results.map { ChatMessage(from: $0) }
        }
    }

    /// Create or update a message (idempotent). Also updates the conversation row.
    public func upsertChatMessage(_ message: ChatMessage) throws {
        let realm = try openRealm()
        try ensureConversationExists(id: message.conversationId) // safety
        try realm.write {
            let obj = realm.object(ofType: ChatMessageLocal.self, forPrimaryKey: message.id) ?? ChatMessageLocal()
            if obj.realm == nil { obj.id = message.id; realm.add(obj, update: .modified) }
            Self.apply(domain: message, to: obj, in: realm)
            Self.touchConversation(for: message, withText: message.text, in: realm)
        }
    }

    /// Append streaming delta and set status; also refresh conversation preview/updatedAt.
    public func appendChatMessage(messageId: UUID, delta: String, status: MessageStatus) throws {
        let realm = try openRealm()
        guard let obj = realm.object(ofType: ChatMessageLocal.self, forPrimaryKey: messageId) else {
            throw ChatDBError.messageNotFound(messageId)
        }
        try realm.write {
            obj.text += delta
            obj.statusRaw = status.rawValue
            // Update convo preview with the growing text
            let stub = ChatMessage(
                id: obj.id,
                conversationId: obj.conversationId,
                role: ChatRole(rawValue: obj.roleRaw) ?? .assistant,
                text: obj.text,
                createdAt: obj.createdAt,
                status: MessageStatus(rawValue: obj.statusRaw) ?? .streaming,
                userId: obj.userId
            )
            Self.touchConversation(for: stub, withText: obj.text, in: realm)
        }
    }

    /// Update a message status and optional error; touch conversation timestamp.
    public func updateChatMessageStatus(messageId: UUID, status: MessageStatus, error: String?) throws {
        let realm = try openRealm()
        guard let obj = realm.object(ofType: ChatMessageLocal.self, forPrimaryKey: messageId) else {
            throw ChatDBError.messageNotFound(messageId)
        }
        try realm.write {
            obj.statusRaw = status.rawValue
            obj.errorDescription = error
            // Touch conversation updatedAt so lists resort if needed
            if let convo = realm.object(ofType: ConversationObject.self, forPrimaryKey: obj.conversationId) {
                convo.updatedAt = Date()
            }
        }
    }

    /// Delete a message (no change to conversation id).
    public func deleteChatMessage(messageId: UUID) throws {
        let realm = try openRealm()
        guard let obj = realm.object(ofType: ChatMessageLocal.self, forPrimaryKey: messageId) else { return }
        try realm.write { realm.delete(obj) }
        // You can choose to backfill preview by reading last message; omitted for simplicity.
    }
    
    /// Delete all messages (updates conversation id).
    public func deleteAllChatMessages(_ conversationId: UUID) throws {
        let realm = try openRealm()
        guard let convo = realm.object(ofType: ConversationObject.self, forPrimaryKey: conversationId) else { return }

        // If ChatMessageLocal has a conversationId field, filter by it.
        let messagesInConversation = realm.objects(ChatMessageLocal.self)
            .filter("conversationId == %@", conversationId)

        try realm.write {
            realm.delete(messagesInConversation)          // delete all messages for this convo
            convo.updatedAt = Date()
            convo.lastMessagePreview = nil
            convo.lastMessageAt = nil
            convo.draftInput = nil
        }
    }
}

// MARK: - Private helpers

extension DatabaseActor {
    private static func apply(domain: ChatMessage, to obj: ChatMessageLocal, in realm: Realm) {
        let local = ChatMessageLocal(from: domain)
        obj.conversationId = local.conversationId
        obj.roleRaw = local.roleRaw
        obj.text = local.text
        obj.createdAt = local.createdAt
        obj.statusRaw = local.statusRaw
        obj.userId = local.userId
        obj.parentId = local.parentId
        obj.errorDescription = local.errorDescription
        obj.attachments.removeAll()
        obj.attachments = local.attachments
        obj.actions = local.actions
    }

    /// Update conversation `updatedAt`, `lastMessageAt`, and `lastMessagePreview`.
    private static func touchConversation(for message: ChatMessage, withText text: String, in realm: Realm) {
        guard let convo = realm.object(ofType: ConversationObject.self, forPrimaryKey: message.conversationId) else { return }
        convo.updatedAt = Date()
        // lastMessageAt reflects the message creation time; keeps chronological sense even with streaming
        convo.lastMessageAt = message.createdAt
        // Update preview only for user/assistant (skip system/tool)
        switch message.role {
        case .user, .assistant:
            convo.lastMessagePreview = makePreview(text)
        default:
            break
        }
    }

    private static func makePreview(_ text: String, maxLen: Int = 140) -> String {
        let trimmed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxLen { return trimmed }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: maxLen)
        return String(trimmed[..<idx]) + "…"
    }
}

enum ConflictTable: String { case events, recurrence_rules, event_overrides, tasks }

extension DatabaseActor {
    func recordConflicts<T: Codable>(_ table: ConflictTable, items: [(local: T, server: T?)], idOf: (T) -> UUID, localVersion: (T) -> Int?, remoteVersion: (T?) -> Int?) throws {
        let realm = try openRealm()
        let enc = JSONEncoder()
        try realm.write {
            for (loc, srv) in items {
                let rowId = idOf(loc)
                let key = "\(table.rawValue):\(rowId.uuidString)"
                let c = SyncConflictLocal()
                c.id = key
                c.table = table.rawValue
                c.rowId = rowId
                c.localVersion = localVersion(loc)
                c.remoteVersion = remoteVersion(srv)
                c.localJSON = String(data: try! enc.encode(loc), encoding: .utf8) ?? "{}"
                c.remoteJSON = srv.flatMap { String(data: try! enc.encode($0), encoding: .utf8) }
                c.createdAt = Date()
                realm.add(c, update: .modified)
            }
        }
    }

    func fetchConflicts(_ table: ConflictTable? = nil) throws -> [SyncConflictLocal] {
        let realm = try openRealm()
        var q = realm.objects(SyncConflictLocal.self)
        if let t = table { q = q.where { $0.table == t.rawValue } }
        return Array(q.sorted(byKeyPath: "createdAt", ascending: true))
    }

    func resolveConflictWithServer(_ key: String) throws {
        let realm = try openRealm()
        if let c = realm.object(ofType: SyncConflictLocal.self, forPrimaryKey: key) {
            try realm.write { c.resolvedAt = Date(); realm.delete(c) }
        }
    }
}
