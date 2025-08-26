//
//  SyncAPI.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation

public protocol SyncAPI: Sendable {
    // EVENTS (you already have these equivalents)
    func insertEventsReturning(_ batch: [EventRemote]) async throws -> [EventRemote]
    func updateEventIfVersionMatches(_ dto: EventRemote) async throws -> EventRemote?
    func fetchEvent(id: UUID) async throws -> EventRemote?
    func fetchEventsToSync(sinceTimestamp: String, sinceID: UUID?, pageSize: Int) async throws -> [EventRemote]

    // RECURRENCE RULES
    func insertRecurrenceRulesReturning(_ batch: [RecurrenceRuleRemote]) async throws -> [RecurrenceRuleRemote]
    func updateRecurrenceRuleIfVersionMatches(_ dto: RecurrenceRuleRemote) async throws -> RecurrenceRuleRemote?
    func fetchRecurrenceRule(id: UUID) async throws -> RecurrenceRuleRemote?
    func fetchRecurrenceRulesToSync(sinceTimestamp: String, sinceID: UUID?, pageSize: Int) async throws -> [RecurrenceRuleRemote]
    
    // EVENT OVERRIDES
    func insertEventOverridesReturning(_ batch: [EventOverrideRemote]) async throws -> [EventOverrideRemote]
    func updateEventOverrideIfVersionMatches(_ dto: EventOverrideRemote) async throws -> EventOverrideRemote?
    func fetchEventOverride(id: UUID) async throws -> EventOverrideRemote?
    func fetchEventOverridesToSync(sinceTimestamp: String, sinceID: UUID?, pageSize: Int) async throws -> [EventOverrideRemote]
    
    // TASKS
    func insertUserTasksReturning(_ batch: [UserTaskRemote]) async throws -> [UserTaskRemote]
    func updateUserTaskIfVersionMatches(_ dto: UserTaskRemote) async throws -> UserTaskRemote?
    func fetchUserTask(id: UUID) async throws -> UserTaskRemote?
    func fetchUserTasksToSync(sinceTimestamp: String, sinceID: UUID?, pageSize: Int) async throws -> [UserTaskRemote]
    func insertUserTasksPayloadReturning(_ batch: [TaskInsertPayload]) async throws -> [UserTaskRemote]
    func updateUserTaskIfVersionMatchesPatch(id: UUID, expectedVersion: Int, patch: TaskUpdatePayload) async throws -> UserTaskRemote?
}
