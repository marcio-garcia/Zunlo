//
//  AIToolRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/16/25.
//

import Foundation

protocol AIToolAPI {
    @discardableResult
    func createEvent(from draft: EventDraft) async throws -> UUID
    func nextUpcomingEvent(after: Date) async throws -> EventDraft?
    func resolveConflictsToday() async throws
    func updateTask(_ task: UserTask) async throws
    @discardableResult
    func createTask(userId: UUID, title: String, dueDate: Date?, priority: UserTaskPriority) async throws -> UUID
    func moveUnfinishedToTomorrow() async throws
}


class AIToolRepository: AIToolAPI {
    
    let eventRepo: EventRepository
    let taskRepo: UserTaskRepository
    let eventEngine: EventSuggestionEngine
    
    init(
        eventRepo: EventRepository,
        taskRepo: UserTaskRepository,
        eventEngine: EventSuggestionEngine
    ) {
        self.eventRepo = eventRepo
        self.taskRepo = taskRepo
        self.eventEngine = eventEngine
    }
    
    func createEvent(from draft: EventDraft) async throws -> UUID {
        let event = toDomain(draft: draft)
        try await eventRepo.upsert(event)
        return event.id
    }
    
    func nextUpcomingEvent(after: Date) async throws -> EventDraft? {
        guard let startDate = await eventEngine.nextEventStart(after: after, on: Date()) else {
            return nil
        }
        
        let filter = EventFilter(startDateRange: startDate...startDate)
        let events = try await eventRepo.fetchEvent(filteredBy: filter)

        guard let event = events.first else { return nil }
        
        return EventDraft(
            id: event.id,
            userId: event.userId,
            title: event.title,
            start: event.startDate,
            end: event.endDate,
            notes: event.notes,
            linkedTaskId: nil
        )
    }
    
    func resolveConflictsToday() async throws {
        
    }
    
    func updateTask(_ task: UserTask) async throws {
        try await taskRepo.upsert(task)
    }
    
    func createTask(userId: UUID, title: String, dueDate: Date?, priority: UserTaskPriority) async throws -> UUID {
        let id = UUID()
        let task = UserTask(
            id: id,
            userId: userId,
            title: title,
            notes: nil,
            isCompleted: false,
            createdAt: Date(),
            updatedAt: Date(),
            dueDate: dueDate,
            priority: priority,
            parentEventId: nil,
            tags: [],
            reminderTriggers: nil,
            deletedAt: nil,
            needsSync: true,
            version: nil
        )
        try await taskRepo.upsert(task)
        return id
    }
    
    func moveUnfinishedToTomorrow() async throws {
        let startOfNextDay = Date().startOfNextDay()
        
        var taskFilter: TaskFilter
        
        taskFilter = TaskFilter(
            isCompleted: false,
            dueDateRange: Date.distantPast...startOfNextDay
        )
        let tasksDueToday = try await taskRepo.fetchTasks(filteredBy: taskFilter)
        
        taskFilter = TaskFilter(
            priority: UserTaskPriorityLocal.high,
            isCompleted: false,
            dueDateRange: Date.distantPast...startOfNextDay
        )
        let tasksHigh = try await taskRepo.fetchTasks(filteredBy: taskFilter)
        
        let tasks = Array(Set(tasksDueToday + tasksHigh))
        
        for task in tasks {
            var t = task
            t.dueDate = Date().addingTimeInterval(86400) // +24h
            try await taskRepo.upsert(t)
        }

//        let startOfDay = Date().startOfDay
//        let eventFilter = EventFilter(endDateRange: startOfDay...startOfNextDay)
//        let events = try await eventRepo.fetchEvent(filteredBy: eventFilter)
//
//        for event in events {
//            var e = event
//            e.startDate = event.startDate.addingTimeInterval(86400) // +24h
//            e.endDate = event.endDate?.addingTimeInterval(86400) // +24h
//            try await eventRepo.upsert(e)
//        }
    }
    
    func toDomain(draft: EventDraft) -> Event {
        Event(
            id: UUID(),
            userId: draft.userId,
            title: draft.title,
            notes: draft.notes,
            startDate: draft.start,
            endDate: draft.end,
            isRecurring: false,
            location: nil,
            createdAt: Date(),
            updatedAt: Date(),
            color: .yellow,
            needsSync: true)
    }
}
