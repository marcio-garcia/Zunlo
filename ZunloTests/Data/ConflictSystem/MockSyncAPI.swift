//
//  MockSyncAPI.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

import Foundation
@testable import Zunlo

// MARK: - Mock SyncAPI

final class MockSyncAPI: SyncAPI {
    // Provide initial "server" snapshot per entity (version, updatedAtRaw preserved)
    var serverTask: UserTaskRemote?
    var serverEvent: EventRemote?
    var serverRule: RecurrenceRuleRemote?
    var serverOverride: EventOverrideRemote?

    // Controls behavior per test
    enum Mode { case success, nilReturn, conflictHTTP, transientHTTP }
    var taskMode: Mode = .success
    var eventMode: Mode = .success
    var ruleMode: Mode = .success
    var overrideMode: Mode = .success

    // ===== Tasks =====
    func updateUserTaskIfVersionMatchesPatch(id: UUID, expectedVersion: Int, patch: TaskUpdatePayload) async throws -> UserTaskRemote? {
        switch taskMode {
        case .conflictHTTP:  throw HTTPStatusError(status: 409, body: nil)
        case .transientHTTP: throw HTTPStatusError(status: 503, body: nil)
        case .nilReturn:     return nil
        case .success:
            guard var s = serverTask, s.id == id, (s.version ?? -1) == expectedVersion else { return nil }
            // Map PATCH → Remote: adjust to your real payload fields if needed
            TaskUpdatePayload.apply(patch: patch, to: &s) // helper defined in tests below
            s.version = (s.version ?? 0) + 1
            serverTask = s
            return s
        }
    }

    // ===== Events =====
    func updateEventIfVersionMatchesPatch(id: UUID, expectedVersion: Int, patch: EventUpdatePayload) async throws -> EventRemote? {
        switch eventMode {
        case .conflictHTTP:  throw HTTPStatusError(status: 409, body: nil)
        case .transientHTTP: throw HTTPStatusError(status: 503, body: nil)
        case .nilReturn:     return nil
        case .success:
            guard var s = serverEvent, s.id == id, (s.version ?? -1) == expectedVersion else { return nil }
            EventUpdatePayload.apply(patch: patch, to: &s)
            s.version = (s.version ?? 0) + 1
            serverEvent = s
            return s
        }
    }

    // ===== Recurrence Rules =====
    func updateRecRuleIfVersionMatchesPatch(id: UUID, expectedVersion: Int, patch: RecRuleUpdatePayload) async throws -> RecurrenceRuleRemote? {
        switch ruleMode {
        case .conflictHTTP:  throw HTTPStatusError(status: 409, body: nil)
        case .transientHTTP: throw HTTPStatusError(status: 503, body: nil)
        case .nilReturn:     return nil
        case .success:
            guard var s = serverRule, s.id == id, (s.version ?? -1) == expectedVersion else { return nil }
            RecRuleUpdatePayload.apply(patch: patch, to: &s)
            s.version = (s.version ?? 0) + 1
            serverRule = s
            return s
        }
    }

    // ===== Overrides =====
    func updateOverrideIfVersionMatchesPatch(id: UUID, expectedVersion: Int, patch: EventOverrideUpdatePayload) async throws -> EventOverrideRemote? {
        switch overrideMode {
        case .conflictHTTP:  throw HTTPStatusError(status: 409, body: nil)
        case .transientHTTP: throw HTTPStatusError(status: 503, body: nil)
        case .nilReturn:     return nil
        case .success:
            guard var s = serverOverride, s.id == id, (s.version ?? -1) == expectedVersion else { return nil }
            EventOverrideUpdatePayload.apply(patch: patch, to: &s)
            s.version = (s.version ?? 0) + 1
            serverOverride = s
            return s
        }
    }
    
    // ===== Chat Messages =====
    func insertChatMessagesPayloadReturning(_ batch: [Zunlo.ChatMessageInsertPayload]) async throws -> [Zunlo.ChatMessageRemote] {
        return []
    }
    
    func fetchChatMessagesToSync(sinceTimestamp: String, sinceID: UUID?, pageSize: Int) async throws -> [Zunlo.ChatMessageRemote] {
        return []
    }


    func insertEventsReturning(_ batch: [Zunlo.EventRemote]) async throws -> [Zunlo.EventRemote] {
        return []
    }
    
    func updateEventIfVersionMatches(_ dto: Zunlo.EventRemote) async throws -> Zunlo.EventRemote? {
        return nil
    }
    
    func fetchEvent(id: UUID) async throws -> Zunlo.EventRemote? {
        return nil
    }
    
    func fetchEventsToSync(sinceTimestamp: String, sinceID: UUID?, pageSize: Int) async throws -> [Zunlo.EventRemote] {
        return []
    }
    
    func insertEventsPayloadReturning(_ batch: [Zunlo.EventInsertPayload]) async throws -> [Zunlo.EventRemote] {
        return []
    }
    
    func insertRecurrenceRulesReturning(_ batch: [Zunlo.RecurrenceRuleRemote]) async throws -> [Zunlo.RecurrenceRuleRemote] {
        return []
    }
    
    func updateRecurrenceRuleIfVersionMatches(_ dto: Zunlo.RecurrenceRuleRemote) async throws -> Zunlo.RecurrenceRuleRemote? {
        return nil
    }
    
    func fetchRecurrenceRule(id: UUID) async throws -> Zunlo.RecurrenceRuleRemote? {
        return nil
    }
    
    func fetchRecurrenceRulesToSync(sinceTimestamp: String, sinceID: UUID?, pageSize: Int) async throws -> [Zunlo.RecurrenceRuleRemote] {
        return []
    }
    
    func insertRecRulesPayloadReturning(_ batch: [Zunlo.RecRuleInsertPayload]) async throws -> [Zunlo.RecurrenceRuleRemote] {
        return []
    }
    
    func insertEventOverridesReturning(_ batch: [Zunlo.EventOverrideRemote]) async throws -> [Zunlo.EventOverrideRemote] {
        return []
    }
    
    func updateEventOverrideIfVersionMatches(_ dto: Zunlo.EventOverrideRemote) async throws -> Zunlo.EventOverrideRemote? {
        return nil
    }
    
    func fetchEventOverride(id: UUID) async throws -> Zunlo.EventOverrideRemote? {
        return nil
    }
    
    func fetchEventOverridesToSync(sinceTimestamp: String, sinceID: UUID?, pageSize: Int) async throws -> [Zunlo.EventOverrideRemote] {
        return []
    }
    
    func insertOverridesPayloadReturning(_ batch: [Zunlo.EventOverrideInsertPayload]) async throws -> [Zunlo.EventOverrideRemote] {
        return []
    }
    
    func insertUserTasksReturning(_ batch: [Zunlo.UserTaskRemote]) async throws -> [Zunlo.UserTaskRemote] {
        return []
    }
    
    func updateUserTaskIfVersionMatches(_ dto: Zunlo.UserTaskRemote) async throws -> Zunlo.UserTaskRemote? {
        return nil
    }
    
    func fetchUserTask(id: UUID) async throws -> Zunlo.UserTaskRemote? {
        return nil
    }
    
    func fetchUserTasksToSync(sinceTimestamp: String, sinceID: UUID?, pageSize: Int) async throws -> [Zunlo.UserTaskRemote] {
        return []
    }
    
    func insertUserTasksPayloadReturning(_ batch: [Zunlo.TaskInsertPayload]) async throws -> [Zunlo.UserTaskRemote] {
        return []
    }
}
