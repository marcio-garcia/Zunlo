//
//  MockDatabaseActor.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

import Foundation
@testable import Zunlo

// MARK: - Mock DB that hides Realm

final class MockDatabaseActor: ConflictDB {

    struct ConflictRec {
        var data: ConflictData
        var status: ConflictStatus
        var attempts: Int
        var lastError: String?
    }

    // Conflicts and applied rows captured in-memory
    private(set) var conflicts: [String: ConflictRec] = [:]

    private(set) var appliedTasks: [UserTaskRemote] = []
    private(set) var appliedEvents: [EventRemote] = []
    private(set) var appliedRules: [RecurrenceRuleRemote] = []
    private(set) var appliedOverrides: [EventOverrideRemote] = []

    // Create a conflict snapshot for tests
    func seedConflict(_ c: ConflictData) {
        conflicts[c.id] = ConflictRec(data: c, status: .pending, attempts: 0, lastError: nil)
    }

    // ===== API used by center / resolvers (mirror DatabaseActor extension) =====

    func fetchPendingConflict(_ conflictId: String) throws -> ConflictData? {
        guard let rec = conflicts[conflictId], rec.status == .pending else { return nil }
        return rec.data
    }

    func bumpConflictAttempt(_ conflictId: String) throws {
        guard var rec = conflicts[conflictId] else { return }
        rec.attempts += 1
        conflicts[conflictId] = rec
    }

    func resolveConflict(conflictId: String, strategy: ResolutionStrategy) throws {
        guard var rec = conflicts[conflictId] else { return }
        rec.status = .autoResolved
        conflicts[conflictId] = rec
    }

    func setConflictNeedsUser(conflictId: String, reason: String) throws {
        guard var rec = conflicts[conflictId] else { return }
        rec.status = .needsUser
        rec.lastError = reason
        conflicts[conflictId] = rec
    }

    func failConflict(conflictId: String, error: Error) throws {
        guard var rec = conflicts[conflictId] else { return }
        rec.status = .failed
        rec.lastError = String(describing: error)
        conflicts[conflictId] = rec
    }

    // ===== Apply into local stores (what resolvers call after a successful PATCH) =====

    func applyRemoteUserTasks(_ rows: [UserTaskRemote]) async throws {
        appliedTasks.append(contentsOf: rows)
    }

    func applyRemoteEvents(_ rows: [EventRemote]) async throws {
        appliedEvents.append(contentsOf: rows)
    }

    func applyRemoteRecurrenceRules(_ rows: [RecurrenceRuleRemote]) async throws {
        appliedRules.append(contentsOf: rows)
    }

    func applyRemoteEventOverrides(_ rows: [EventOverrideRemote]) async throws {
        appliedOverrides.append(contentsOf: rows)
    }
}
