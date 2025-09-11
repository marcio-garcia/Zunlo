//
//  DomainRepositories.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation

/// Your domain façade (implement with your repositories / DatabaseActor)
protocol DomainRepositories: Sendable {
    func versionForTask(id: UUID) async -> Int?
    func versionForEvent(id: UUID) async -> Int?
    func apply(task: UserTaskRemote) async throws
    func apply(event: EventRemote) async throws
    func apply(recurrence: RecurrenceRuleRemote) async throws
    func apply(override: EventOverrideRemote) async throws
    func fetchEvents(start: Date, end: Date) async throws -> [Event]
    func fetchOccurrences() async throws -> [EventOccurrence]
    func fetchTasks(range: Range<Date>) async throws -> [UserTask]
    func fetchTasks(filter: TaskFilter?) async throws -> [UserTask]
}
