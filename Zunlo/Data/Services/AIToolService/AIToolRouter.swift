//
//  AIToolRouter.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation

enum ToolRoutingError: LocalizedError {
    case missingVersion(entity: String, id: UUID)
    case occurrenceRequired
    var errorDescription: String? {
        switch self {
        case .missingVersion(let e, let id): return "Missing local version for \(e) \(id). Sync first."
        case .occurrenceRequired: return "This change targets a single occurrence; need an occurrenceDate."
        }
    }
}

/// Single responsibility: map a ToolEnvelope to the right ToolService call,
/// inject `version`/ids, and apply server snapshots to local stores.
final public class AIToolRouter {
    private let tools: AIToolService
    private let repo: DomainRepositories
    private let reason = "from tool call"

    public init(tools: AIToolService, repo: DomainRepositories) {
        self.tools = tools
        self.repo = repo
    }

    /// Dispatch one tool call. Returns a short user-facing note for the chat.
    func dispatch(_ env: AIToolEnvelope) async throws -> String {
        switch env.name {

        case "createTask": do {
            let args = try JSONDecoder.decoder().decode(CreateTaskArgs.self, from: Data(env.arguments.rawJSON.utf8))
            let p = CreateTaskPayloadWire(
                idempotencyKey: UUID().uuidString,
                reason: reason,
                task: args.task
            )
            let res = try await tools.createTask(p)
            if let t = res.task { try await repo.apply(task: t) }
            return "✅ Task created"
        }

        case "updateTask": do {
            let args = try JSONDecoder.decoder().decode(UpdateTaskArgs.self, from: Data(env.arguments.rawJSON.utf8))
            guard let v = await repo.versionForTask(id: args.taskId) else {
                throw ToolRoutingError.missingVersion(entity: "task", id: args.taskId)
            }
            let p = UpdateTaskPayloadWire(
                idempotencyKey: UUID().uuidString,
                reason: reason,
                taskId: args.taskId,
                version: v,
                patch: args.patch
            )
            let res = try await tools.updateTask(p)
            if let t = res.task { try await repo.apply(task: t) }
            return "✅ Task updated"
        }

        case "deleteTask": do {
            let args = try JSONDecoder.decoder().decode(DeleteTaskArgs.self, from: Data(env.arguments.rawJSON.utf8))
            guard let v = await repo.versionForTask(id: args.taskId) else {
                throw ToolRoutingError.missingVersion(entity: "task", id: args.taskId)
            }
            let p = DeleteTaskPayloadWire(
                idempotencyKey: UUID().uuidString,
                reason: reason,
                taskId: args.taskId,
                version: v
            )
            let res = try await tools.deleteTask(p)
            if let t = res.task { try await repo.apply(task: t) }
            return "🗑️ Task deleted"
        }

        case "createEvent": do {
            let args = try JSONDecoder.decoder().decode(CreateEventArgs.self, from: Data(env.arguments.rawJSON.utf8))
            let p = CreateEventPayloadWire(
                idempotencyKey: UUID().uuidString,
                reason: reason,
                event: args.event
            )
            let res = try await tools.createEvent(p)
            if let e = res.event { try await repo.apply(event: e) }
            if let r = res.recurrenceRule { try await repo.apply(recurrence: r) }
            return "📅 Event created"
        }

        case "updateEvent": do {
            let args = try JSONDecoder.decoder().decode(UpdateEventArgs.self, from: Data(env.arguments.rawJSON.utf8))
            guard let v = await repo.versionForEvent(id: args.eventId) else {
                throw ToolRoutingError.missingVersion(entity: "event", id: args.eventId)
            }
            if (args.editScope == .override || args.editScope == .this_and_future), args.occurrenceDate == nil {
                throw ToolRoutingError.occurrenceRequired
            }
            let p = UpdateEventPayloadWire(
                idempotencyKey: UUID().uuidString,
                reason: reason,
                eventId: args.eventId,
                version: v,
                editScope: args.editScope,
                occurrenceDate: args.occurrenceDate,
                patch: args.patch
            )
            let res = try await tools.updateEvent(p)
            if let e = res.event { try await repo.apply(event: e) }
            if let r = res.recurrenceRule { try await repo.apply(recurrence: r) }
            if let o = res.override { try await repo.apply(override: o) }
            
            switch args.editScope {
            case .single: return "✏️ Event updated"
            case .override: return "✏️ Occurrence updated"
            case .this_and_future: return "✂️ Series split & updated"
            case .entire_series: return "✏️ Series updated"
            }
        }

        case "deleteEvent": do {
            let args = try JSONDecoder.decoder().decode(DeleteEventArgs.self, from: Data(env.arguments.rawJSON.utf8))
            guard let v = await repo.versionForEvent(id: args.eventId) else {
                throw ToolRoutingError.missingVersion(entity: "event", id: args.eventId)
            }
            if (args.editScope == .override || args.editScope == .this_and_future), args.occurrenceDate == nil {
                throw ToolRoutingError.occurrenceRequired
            }
            let p = DeleteEventPayloadWire(
                idempotencyKey: UUID().uuidString,
                reason: reason,
                eventId: args.eventId,
                version: v,
                editScope: args.editScope,
                occurrenceDate: args.occurrenceDate
            )
            let res = try await tools.deleteEvent(p)
            if let e = res.event { try await repo.apply(event: e) }
            if let o = res.override { try await repo.apply(override: o) }
            
            switch args.editScope {
            case .single: return "🗑️ Event deleted"
            case .override: return "🚫 Occurrence cancelled"
            case .this_and_future: return "✂️ Future series deleted"
            case .entire_series: return "🗑️ Series deleted"
            }
        }

        case "getAgenda":
            return "📋 Pulled agenda."

        case "planWeek":
            return "🧭 Proposed plan ready."

        default:
            return "ℹ️ Unrecognized tool: \(env.name)"
        }
    }
}
