//
//  DomainRepositories.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation

/// Your domain façade (implement with your repositories / DatabaseActor)
public protocol DomainRepositories {
    func versionForTask(id: UUID) async -> Int?
    func versionForEvent(id: UUID) async -> Int?
    func apply(task: UserTaskRemote) async throws
    func apply(event: EventRemote) async throws
    func apply(recurrence: RecurrenceRuleRemote) async throws
    func apply(override: EventOverrideRemote) async throws
}
