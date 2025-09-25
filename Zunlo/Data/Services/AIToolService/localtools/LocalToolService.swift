//
//  LocalToolService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/10/25.
//

import Foundation

final class LocalToolService: AIToolServiceAPI {
    private let taskRepo: UserTaskRepository
    private let eventRepo: EventRepository
    private let auth: AuthProviding
    
    init(taskRepo: UserTaskRepository, eventRepo: EventRepository, auth: AuthProviding) {
        self.taskRepo = taskRepo
        self.eventRepo = eventRepo
        self.auth = auth
    }
    
    func createTask(_ payload: CreateTaskPayloadWire) async throws -> TaskMutationResult {
        guard let userId = await auth.userId else {
            return TaskMutationResult(
                ok: false, task: UserTaskRemote(input: payload.task, userId: UUID()), code: nil, message: "Not authenticated"
            )
        }
        let task = UserTask(input: payload.task, userId: userId)
        try await taskRepo.upsert(task)
        return TaskMutationResult(ok: true, task: UserTaskRemote(domain: task), code: nil, message: "Task created")
    }
    
    func updateTask(_ payload: UpdateTaskPayloadWire) async throws -> TaskMutationResult {
        guard let userId = await auth.userId else {
            return TaskMutationResult(
                ok: false, task: UserTaskRemote(input: payload.patch, userId: UUID()), code: nil, message: "Not authenticated"
            )
        }
        let task = UserTask(input: payload.patch, userId: userId)
        try await taskRepo.upsert(task)
        return TaskMutationResult(ok: true, task: UserTaskRemote(domain: task), code: nil, message: "Task updated")
    }
    
    func deleteTask(_ payload: DeleteTaskPayloadWire) async throws -> TaskMutationResult {
        guard let task = try await taskRepo.fetchTask(id: payload.taskId) else {
            return TaskMutationResult(
                ok: false, task: nil, code: nil, message: "There is no task with id=\(payload.taskId)"
            )
        }
        try await taskRepo.delete(task)
        return TaskMutationResult(ok: true, task: nil, code: nil, message: "Task deleted")
    }
    
    func createEvent(_ payload: CreateEventPayloadWire) async throws -> EventMutationResult {
        guard let userId = await auth.userId else {
            return EventMutationResult(
                ok: false,
                event: EventRemote(input: payload.event, userId: UUID()),
                recurrenceRule: nil, override: nil, code: nil, message: "Not authenticated"
            )
        }
        let event = Event(input: payload.event, userId: userId)
        try await eventRepo.upsert(event)
        return EventMutationResult(ok: true, event: EventRemote(domain: event), recurrenceRule: nil, override: nil, code: nil, message: "Event created")
    }
    
    func updateEvent(_ payload: UpdateEventPayloadWire) async throws -> EventMutationResult {
        guard let userId = await auth.userId else {
            return EventMutationResult(ok: false, event: EventRemote(input: payload.patch, userId: UUID()),
                                       recurrenceRule: nil, override: nil, code: nil, message: "Not authenticated")
        }
        let event = Event(input: payload.patch, userId: userId)
        try await eventRepo.upsert(event)
        return EventMutationResult(ok: true, event: EventRemote(domain: event), recurrenceRule: nil, override: nil, code: nil, message: "Event updated")
    }
    
    func deleteEvent(_ payload: DeleteEventPayloadWire) async throws -> EventMutationResult {
        guard let event = try await eventRepo.fetchEvent(by: payload.eventId) else {
            return EventMutationResult(ok: false, event: nil,
                                       recurrenceRule: nil, override: nil, code: nil, message: "There is no event with id=\(payload.eventId)")
        }
        try await eventRepo.delete(id: event.id)
        return EventMutationResult(ok: true, event: nil, recurrenceRule: nil, override: nil, code: nil, message: "Event deleted")
    }
}
