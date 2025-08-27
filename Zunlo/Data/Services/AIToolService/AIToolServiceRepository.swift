//
//  AIToolServiceRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation

class AIToolServiceRepository: DomainRepositories, @unchecked Sendable {
    
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
    
    func fetchEvents(start: Date, end: Date) async throws -> [Event] {
        let startRange = start.startOfDay...start.startOfNextDay()
        let endRange = end.startOfDay...end.startOfNextDay()
        let filter = EventFilter(userId: nil, startDateRange: startRange, endDateRange: endRange)
        return try await eventRepo.fetchEvent(filteredBy: filter)
    }
    
    func fetchOccurrences(userId: UUID) async throws -> [EventOccurrence] {
        return try await eventRepo.fetchOccurrences(for: userId)
    }
    
    func fetchTasks(range: Range<Date>) async throws -> [UserTask] {
        let filter = TaskFilter(isCompleted: false, dueDateRange: range.lowerBound...range.upperBound)
        return try await taskRepo.fetchTasks(filteredBy: filter)
    }
}
