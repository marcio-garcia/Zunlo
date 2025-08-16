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
    func createTask(title: String, dueDate: Date?, priority: UserTaskPriority) async throws -> UUID
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
        guard let event = try await eventRepo.fetchEvent(startAt: startDate) else {
            return nil
        }
        return EventDraft(
            id: event.id,
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
    
    func createTask(title: String, dueDate: Date?, priority: UserTaskPriority) async throws -> UUID {
        let id = UUID()
        let task = UserTask(
            id: id,
            userId: nil,
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
            needsSync: true
        )
        try await taskRepo.upsert(task)
        return id
    }
    
    func toDomain(draft: EventDraft) -> Event {
        Event(
            id: UUID(),
            userId: nil,
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
