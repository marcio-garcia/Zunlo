//
//  DatabaseActor.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import RealmSwift

actor DatabaseActor {
    private let config: Realm.Configuration
    // Keeps the in-memory realm alive for the test's lifetime
    private var anchorRealm: Realm?
    
    /// Use `keepAliveAnchor: true` when using in-memory configs in tests.
    init(
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
                if let existing = realm.object(ofType: EventLocal.self, forPrimaryKey: r.id),
                   existing.needsSync == true { continue } // v1 trade-off
                let obj = realm.object(ofType: EventLocal.self, forPrimaryKey: r.id)
                ?? EventLocal(value: ["id": r.id])
                obj.getUpdateFields(r)
                obj.deletedAt = r.deleted_at
                obj.needsSync = false
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
                if let existing = realm.object(ofType: RecurrenceRuleLocal.self, forPrimaryKey: r.id),
                   existing.needsSync == true { continue }
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
                let id = r.id // non-optional
                if let existing = realm.object(ofType: EventOverrideLocal.self, forPrimaryKey: id),
                   existing.needsSync == true { continue }
                let obj = realm.object(ofType: EventOverrideLocal.self, forPrimaryKey: id)
                    ?? EventOverrideLocal(remote: r)
                obj.getUpdateFields(r)
                realm.add(obj, update: .modified)
            }
        }
    }
    
    // --------------------------------------------------------
    // MARK: Events
    // --------------------------------------------------------

    func fetchAllEventsSorted() throws -> [Event] {
        let realm = try openRealm()
        let results = realm.objects(EventLocal.self)
            .sorted(byKeyPath: "startDate", ascending: true)
        return results.map { Event(local: $0) }
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

    func upsertEvent(from domain: Event, userId: UUID?) throws {
        let realm = try openRealm()
        try realm.write {
            let obj = realm.object(ofType: EventLocal.self, forPrimaryKey: domain.id) ?? EventLocal(domain: domain)
            obj.getUpdateFields(domain)
            if obj.userId == nil { obj.userId = userId }
            obj.updatedAt = Date()         // local stamp (server will overwrite)
            obj.needsSync = true
            realm.add(obj, update: .modified)
        }
    }

    func softDeleteEvent(id: UUID) throws {
        let realm = try openRealm()
        try realm.write {
            guard let existing = realm.object(ofType: EventLocal.self, forPrimaryKey: id) else { return }
            existing.deletedAt = Date()
            existing.updatedAt = Date()
            existing.needsSync = true
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
                if let existing = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: id),
                   existing.needsSync == true { continue } // v1 trade-off: don't stomp local dirty
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
            predicates.append(NSPredicate(format: "priority == %@", priority.rawValue))
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

    // --------------------------------------------------------
    // MARK: Chat
    // --------------------------------------------------------

    func fetchAllChatMessages() throws -> [ChatMessage] {
        let realm = try openRealm()
        let results = realm.objects(ChatMessageLocal.self)
            .sorted(byKeyPath: "createdAt", ascending: true)
        return results.map { ChatMessage(local: $0) }
    }

    func saveChatMessage(_ message: ChatMessage) throws {
        let realm = try openRealm()
        try realm.write {
            let local = ChatMessageLocal(
                id: message.id,
                userId: message.userId,
                message: message.message,
                createdAt: message.createdAt,
                isFromUser: message.isFromUser
            )
            realm.add(local, update: .all)
        }
    }

    func deleteAllChatMessages() throws {
        let realm = try openRealm()
        try realm.write { realm.delete(realm.objects(ChatMessageLocal.self)) }
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
        newEvent: Event,
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
            let newDomain = Event(
                id: newEventId,
                userId: userId,
                title: newEvent.title,
                notes: newEvent.notes,
                startDate: newEvent.startDate,
                endDate: newEvent.endDate,
                isRecurring: newEvent.isRecurring,
                location: newEvent.location,
                createdAt: newEvent.createdAt,
                updatedAt: now,
                color: newEvent.color,
                reminderTriggers: newEvent.reminderTriggers,
                deletedAt: nil,
                needsSync: true
            )
            let newLocal = EventLocal(domain: newDomain)
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
                    needsSync: true
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
