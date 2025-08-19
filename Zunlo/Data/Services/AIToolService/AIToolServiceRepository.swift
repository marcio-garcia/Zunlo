//
//  AIToolServiceRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation

class AIToolServiceRepository: DomainRepositories {
    
    private let taskRepo: UserTaskRepository
    private let eventRepo: EventRepository
    
    init(taskRepo: UserTaskRepository, eventRepo: EventRepository) {
        self.taskRepo = taskRepo
        self.eventRepo = eventRepo
    }
    
    func versionForTask(id: UUID) async -> Int? {
        let task = try? await taskRepo.fetchTask(id: id)
        return task?.version
    }
    
    func versionForEvent(id: UUID) async -> Int? {
        let event = try? await eventRepo.fetchEvent(by: id)
        return event?.version
    }
    
    func apply(task: UserTaskRemote) async throws {
        try await taskRepo.apply(rows: [task])
    }
    
    func apply(event: EventRemote) async throws {
        try await eventRepo.apply(rows: [event])
    }
    
    func apply(recurrence: RecurrenceRuleRemote) async throws {
        try await eventRepo.apply(rows: [recurrence])
    }
    
    func apply(override: EventOverrideRemote) async throws {
        try await eventRepo.apply(rows: [override])
    }
}
