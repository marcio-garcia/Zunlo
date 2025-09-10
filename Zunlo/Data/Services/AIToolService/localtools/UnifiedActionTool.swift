//
//  UnifiedActionTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/9/25.
//

import Foundation

// MARK: - Lightweight UI payloads preserved from your tool router
public struct ChatInsert {
    public let text: AttributedString
    public let attachments: [ChatAttachment]
    public let actions: [ChatMessageAction]
    public init(text: AttributedString, attachments: [ChatAttachment], actions: [ChatMessageAction]) {
        self.text = text
        self.attachments = attachments
        self.actions = actions
    }
}

public struct ToolDispatchResult {
    public let note: String            // short note the model/User sees
    public let attributedText: AttributedString?
    public let ui: ChatInsert?         // optional chat bubble to insert
    public init(note: String, attributedText: AttributedString? = nil, ui: ChatInsert? = nil) {
        self.note = note
        self.attributedText = attributedText
        self.ui = ui
    }
}

// MARK: - Minimal error surface
public enum UnifiedToolError: LocalizedError {
    case missingTaskVersion(id: UUID)
    case missingEventVersion(id: UUID)
    case occurrenceDateRequired
    case service(String)

    public var errorDescription: String? {
        switch self {
        case .missingTaskVersion(let id): return "Missing local version for task \(id). Provide a version or sync first."
        case .missingEventVersion(let id): return "Missing local version for event \(id). Provide a version or sync first."
        case .occurrenceDateRequired: return "This change targets a single occurrence; provide an occurrenceDate."
        case .service(let msg): return msg
        }
    }
}

// MARK: - Unified class
final class UnifiedActionTool {
    private let userId: UUID
    private let service: AIToolService
    private let repo: DomainRepositories
    private let calendar: Calendar

    init(userId: UUID, service: AIToolService, repo: DomainRepositories, calendar: Calendar = .appDefault) {
        self.userId = userId
        self.service = service
        self.repo = repo
        self.calendar = calendar
    }

    // MARK: Tasks
    @discardableResult
    public func createTask(_ args: CreateTaskArgs) async throws -> ToolDispatchResult {
        let payload = CreateTaskPayloadWire(idempotencyKey: UUID().uuidString, reason: "unified", task: args.task)
        let res = try await service.createTask(payload)
        if let t = res.task { try await repo.apply(task: t) }
        return .init(note: "Task created")
    }

    @discardableResult
    public func updateTask(_ args: UpdateTaskArgs, version: Int? = nil) async throws -> ToolDispatchResult {
        let v = try await ensureTaskVersion(id: args.taskId, provided: version)
        let payload = UpdateTaskPayloadWire(idempotencyKey: UUID().uuidString, reason: "unified", taskId: args.taskId, version: v, patch: args.patch)
        let res = try await service.updateTask(payload)
        if let t = res.task { try await repo.apply(task: t) }
        return .init(note: "Task updated")
    }

    @discardableResult
    public func deleteTask(_ args: DeleteTaskArgs, version: Int? = nil) async throws -> ToolDispatchResult {
        let v = try await ensureTaskVersion(id: args.taskId, provided: version)
        let payload = DeleteTaskPayloadWire(idempotencyKey: UUID().uuidString, reason: "unified", taskId: args.taskId, version: v)
        let res = try await service.deleteTask(payload)
        if let t = res.task { try await repo.apply(task: t) }
        return .init(note: "Task deleted")
    }

    /// Convenience: reschedule a task by setting its dueDate in a patch.
    @discardableResult
    public func rescheduleTask(taskId: UUID, newDueDate: Date, version: Int? = nil) async throws -> ToolDispatchResult {
        let patch = TaskPatchInput(dueDate: newDueDate)
        let args = UpdateTaskArgs(taskId: taskId, patch: patch)
        return try await updateTask(args, version: version)
    }

    // MARK: Events
    @discardableResult
    public func createEvent(_ input: EventCreateInput) async throws -> ToolDispatchResult {
        let payload = CreateEventPayloadWire(idempotencyKey: UUID().uuidString, reason: "unified", event: input)
        let res = try await service.createEvent(payload)
        if let e = res.event { try await repo.apply(event: e) }
        if let r = res.recurrenceRule { try await repo.apply(recurrence: r) }
        return .init(note: "Event created")
    }

    @discardableResult
    public func updateEvent(_ args: UpdateEventArgs, version: Int? = nil) async throws -> ToolDispatchResult {
        if (args.editScope == .override || args.editScope == .this_and_future), args.occurrenceDate == nil {
            throw UnifiedToolError.occurrenceDateRequired
        }
        let v = try await ensureEventVersion(id: args.eventId, provided: version)
        let payload = UpdateEventPayloadWire(idempotencyKey: UUID().uuidString, reason: "unified", eventId: args.eventId, version: v, editScope: args.editScope, occurrenceDate: args.occurrenceDate, patch: args.patch)
        let res = try await service.updateEvent(payload)
        if let e = res.event { try await repo.apply(event: e) }
        if let r = res.recurrenceRule { try await repo.apply(recurrence: r) }
        if let o = res.override { try await repo.apply(override: o) }
        switch args.editScope {
        case .single: return .init(note: "Event updated")
        case .override: return .init(note: "Occurrence updated")
        case .this_and_future: return .init(note: "Series split & updated")
        case .entire_series: return .init(note: "Series updated")
        }
    }

    @discardableResult
    public func deleteEvent(_ args: DeleteEventArgs, version: Int? = nil) async throws -> ToolDispatchResult {
        if (args.editScope == .override || args.editScope == .this_and_future), args.occurrenceDate == nil {
            throw UnifiedToolError.occurrenceDateRequired
        }
        let v = try await ensureEventVersion(id: args.eventId, provided: version)
        let payload = DeleteEventPayloadWire(idempotencyKey: UUID().uuidString, reason: "unified", eventId: args.eventId, version: v, editScope: args.editScope, occurrenceDate: args.occurrenceDate)
        let res = try await service.deleteEvent(payload)
        if let e = res.event { try await repo.apply(event: e) }
        if let o = res.override { try await repo.apply(override: o) }
        switch args.editScope {
        case .single: return .init(note: "Event deleted")
        case .override: return .init(note: "Occurrence cancelled")
        case .this_and_future: return .init(note: "Future series deleted")
        case .entire_series: return .init(note: "Series deleted")
        }
    }

    /// Convenience: reschedule an event by setting new start/end in a patch.
    /// If you target an occurrence or split, pass `editScope` and `occurrenceDate` accordingly.
    @discardableResult
    public func rescheduleEvent(eventId: UUID, newStart: Date, newEnd: Date, editScope: EventEditScope = .single, occurrenceDate: Date? = nil, version: Int? = nil) async throws -> ToolDispatchResult {
        let patch = EventPatchInput(startDatetime: newStart, endDatetime: newEnd)
        let args = UpdateEventArgs(eventId: eventId, editScope: editScope, occurrenceDate: occurrenceDate, patch: patch)
        return try await updateEvent(args, version: version)
    }

    // MARK: Agenda & Planning
    @discardableResult
    public func getAgenda(_ args: GetAgendaArgs) async throws -> ToolDispatchResult {
        let (range, tz) = resolveWindow(from: args)
        let result = try await service.getAgenda(args: args, calculatedRange: range, timezone: tz)
        let attachment = ChatAttachment.json(schema: result.schema, json: result.json)
        let ui = ChatInsert(text: result.attributed, attachments: [attachment], actions: [.copyText, .copyAttachment(attachment.id), .sendAttachmentToAI(attachment.id)])
        return .init(note: result.text, attributedText: result.attributed, ui: ui)
    }

    @discardableResult
    public func planWeek(_ args: PlanWeekArgs) async throws -> ToolDispatchResult {
        let start = calendar.startOfDay(for: args.startDate)
        let horizonDays = (args.horizon?.lowercased() == "day") ? 1 : 7
        var constraints = Constraints()
        if let const = args.constraints {
            // TODO: Convert args into Constraints
//            constraints = Constraints(workHours: [Int : (start: DateComponents, end: DateComponents)]?, minFocusMins: Int, maxFocusMins: Int)
        }
        let res = try await service.planWeek(userId: userId, start: start, horizonDays: horizonDays, timezone: .current, objectives: args.objectives ?? [], constraints: constraints)
        let json = try JSONEncoder.encoder().encode(res)
        let out = String(data: json, encoding: .utf8) ?? "{}"
        return .init(note: out)
    }

    // MARK: - Private helpers
    private func ensureTaskVersion(id: UUID, provided: Int?) async throws -> Int {
        if let v = provided { return v }
        guard let v = await repo.versionForTask(id: id) else { throw UnifiedToolError.missingTaskVersion(id: id) }
        return v
    }

    private func ensureEventVersion(id: UUID, provided: Int?) async throws -> Int {
        if let v = provided { return v }
        guard let v = await repo.versionForEvent(id: id) else { throw UnifiedToolError.missingEventVersion(id: id) }
        return v
    }

    private func resolveWindow(from args: GetAgendaArgs, calendar calIn: Calendar = .autoupdatingCurrent, timeZone tz: TimeZone = .current, weekMode: WeekMode = .rolling7) -> (range: Range<Date>, timezone: TimeZone) {
        var cal = calIn; cal.timeZone = tz
        let now = Date(); let startOfToday = cal.startOfDay(for: now)
        let oneDay: TimeInterval = 86_400
        switch args.dateRange {
        case .today:
            let start = startOfToday
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(oneDay)
            return (start..<end, tz)
        case .tomorrow:
            let start = cal.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(oneDay)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(oneDay)
            return (start..<end, tz)
        case .week:
            switch weekMode {
            case .rolling7:
                let start = startOfToday
                let end = cal.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * oneDay)
                return (start..<end, tz)
            case .calendarWeek:
                let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
                let end = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start.addingTimeInterval(7 * oneDay)
                return (start..<end, tz)
            }
        case .custom:
            if let s = args.start, let e = args.end, e > s { return (s..<e, tz) }
            let start = startOfToday
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(oneDay)
            return (start..<end, tz)
        }
    }

    private enum WeekMode { case rolling7, calendarWeek }
}
