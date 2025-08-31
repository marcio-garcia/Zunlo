//
//  AIToolRouter.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation
import ZunloHelpers

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

public struct ChatInsert {
    public let text: AttributedString
    public let attachments: [ChatAttachment]
    public let actions: [ChatMessageAction]
}

public struct ToolDispatchResult {
    public let note: String            // short note that the model sees
    public let ui: ChatInsert?         // optional chat bubble to insert
    
    public init(note: String, ui: ChatInsert? = nil) {
        self.note = note
        self.ui = ui
    }
}

public protocol ToolRouter {
    func dispatch(_ env: AIToolEnvelope) async throws -> ToolDispatchResult
}

/// Single responsibility: map a ToolEnvelope to the right ToolService call,
/// inject `version`/ids, and apply server snapshots to local stores.
public class AIToolRouter: ToolRouter {
    private let userId: UUID
    private let tools: AIToolService
    private let repo: DomainRepositories
    private let calendar: Calendar
    private let reason = "from tool call"
    
    init(
        userId: UUID,
        tools: AIToolService,
        repo: DomainRepositories,
        calendar: Calendar = .appDefault
    ) {
        self.userId = userId
        self.tools = tools
        self.repo = repo
        self.calendar = calendar
    }

    /// Dispatch one tool call. Returns a short user-facing note for the chat.
    public func dispatch(_ env: AIToolEnvelope) async throws -> ToolDispatchResult {
        let timezone = calendar.timeZone.identifier
        let normalizedArgsJSON = try ToolTimeNormalizer.normalize(
            json: env.argsJSON,
            tzId: timezone,
            onlyKeys: ["startDate","endDate","dueDate"]
        )
        
        switch env.name {

        case "createTask": do {
            let args = try JSONDecoder.makeDecoder().decode(CreateTaskArgs.self, from: Data(normalizedArgsJSON.utf8))
            let p = CreateTaskPayloadWire(
                idempotencyKey: UUID().uuidString,
                reason: reason,
                task: args.task
            )
            let res = try await tools.createTask(p)
            if let t = res.task { try await repo.apply(task: t) }
            return ToolDispatchResult(note: "Task created")
        }

        case "updateTask": do {
            let args = try JSONDecoder.makeDecoder().decode(UpdateTaskArgs.self, from: Data(normalizedArgsJSON.utf8))
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
            return ToolDispatchResult(note: "Task updated")
        }

        case "deleteTask": do {
            let args = try JSONDecoder.makeDecoder().decode(DeleteTaskArgs.self, from: Data(normalizedArgsJSON.utf8))
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
            return ToolDispatchResult(note: "Task deleted")
        }

        case "createEvent": do {
            let args = try JSONDecoder.makeDecoder().decode(CreateEventArgs.self, from: Data(normalizedArgsJSON.utf8))
            let p = CreateEventPayloadWire(
                idempotencyKey: UUID().uuidString,
                reason: reason,
                event: args.event
            )
            let res = try await tools.createEvent(p)
            if let e = res.event { try await repo.apply(event: e) }
            if let r = res.recurrenceRule { try await repo.apply(recurrence: r) }
            return ToolDispatchResult(note: "Event created")
        }

        case "updateEvent": do {
            let args = try JSONDecoder.makeDecoder().decode(UpdateEventArgs.self, from: Data(normalizedArgsJSON.utf8))
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
            case .single: return ToolDispatchResult(note: "Event updated")
            case .override: return ToolDispatchResult(note: "Occurrence updated")
            case .this_and_future: return ToolDispatchResult(note: "Series split & updated")
            case .entire_series: return ToolDispatchResult(note: "Series updated")
            }
        }

        case "deleteEvent": do {
            let args = try JSONDecoder.makeDecoder().decode(DeleteEventArgs.self, from: Data(normalizedArgsJSON.utf8))
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
            case .single: return ToolDispatchResult(note: "Event deleted")
            case .override: return ToolDispatchResult(note: "Occurrence cancelled")
            case .this_and_future: return ToolDispatchResult(note: "Future series deleted")
            case .entire_series: return ToolDispatchResult(note: "Series deleted")
            }
        }

        case "getAgenda":
            // {"dateRange":"tomorrow","start":"2025-08-21T00:00:00-03:00","end":"2025-08-22T00:00:00-03:00"}
            
            var args: GetAgendaArgs?
            do {
                args = try JSONDecoder.makeDecoder().decode(GetAgendaArgs.self, from: Data(normalizedArgsJSON.utf8))
            } catch let error as DecodingError {
                let err = formatDecodingError(error)
                print("ERROR: \(err)")
                args = GetAgendaArgs(dateRange: .today, start: nil, end: nil)
            }
            let (range, tz) = resolveWindow(from: args!) // today/tomorrow/week/custom
            
            let result = try await tools.getAgenda(args: args!, calculatedRange: range, timezone: tz)
            
            // Split output
            let attachment = ChatAttachment.json(schema: result.schema, json: result.json)

            let ui = ChatInsert(
                text: result.attributed,
                attachments: [attachment],
                actions: [
                    .copyText,
                    .copyAttachment(attachment.id),
                    .sendAttachmentToAI(attachment.id)
                ]
            )
            return ToolDispatchResult(note: result.text, ui: ui)

        case "planWeek":
            var args = try? JSONDecoder.makeDecoder().decode(PlanWeekArgs.self, from: Data(normalizedArgsJSON.utf8))
            if args == nil {
                args = PlanWeekArgs(startDate: Date(), objectives: [], constraints: nil, horizon: "7")
            }
            let start = args!.startDate.startOfDay()
            let horizonDays = (args!.horizon == "day") ? 1 : 7
//            let agendaComputer = LocalAgendaComputer(toolRepo: repo)
//            let weekPlanner = LocalWeekPlanner(agenda: agendaComputer, toolRepo: repo)
//            let res = try await weekPlanner.proposePlan(
//                start: start,
//                horizonDays: horizonDays,
//                timezone: .current,
//                objectives: args!.objectives ?? [],
//                constraints: nil
//            )
            
            let res = try await tools.planWeek(
                userId: userId,
                start: start,
                horizonDays: horizonDays,
                timezone: .current,
                objectives: [],
                constraints: nil
            )
            let json = try JSONEncoder.encoder().encode(res)
            let out = String(data: json, encoding: .utf8) ?? "{}"
            return ToolDispatchResult(note: out)
//            if c.origin == .requiredAction, let rid = c.responseId {
//                try? await aiChatService.submitToolOutputs(responseId: rid, outputs: [.init(tool_call_id: c.id, output: out)])
//            } else {
//                appendToolBubble("🧭 Proposed \(res.blocks.count) blocks")
//            }
//            return "🧭 Proposed plan ready."

        default:
            return ToolDispatchResult(note: "Unrecognized tool: \(env.name)")
        }
    }
}

extension AIToolRouter {
    /// Convert tool args into a concrete [start, end) window in a timezone.
    @inlinable
    func resolveWindow(from args: GetAgendaArgs,
                       calendar calIn: Calendar = .autoupdatingCurrent,
                       timeZone tz: TimeZone = .current,
                       weekMode: WeekMode = .rolling7) -> (range: Range<Date>, timezone: TimeZone)
    {
        var cal = calIn
        cal.timeZone = tz

        let now = Date()
        let startOfToday = cal.startOfDay(for: now)

        let oneDay: TimeInterval = 24 * 60 * 60

        switch args.dateRange {
        case .today:
            let start = startOfToday
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(oneDay)
            return (range: start..<end, tz)

        case .tomorrow:
            let start = cal.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(oneDay)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(oneDay)
            return (range: start..<end, tz)

        case .week:
            switch weekMode {
            case .rolling7:
                // [today 00:00, today+7d 00:00)
                let start = startOfToday
                let end = cal.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * oneDay)
                return (range: start..<end, tz)

            case .calendarWeek:
                // Current calendar week (Mon–Sun or locale’s setting) as [weekStart, nextWeekStart)
                let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
                let next = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart.addingTimeInterval(7 * oneDay)
                return (range: weekStart..<next, tz)
            }

        case .custom:
            // Use provided start/end; if missing/invalid, fall back to today.
            guard let s = args.start, let e = args.end, e > s else {
                let start = startOfToday
                let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(oneDay)
                return (range: start..<end, tz)
            }
            // Normalize to timezone boundary if you want, otherwise just return as-is:
            return (range: s..<e, tz)
        }
    }

    /// Choose how "week" is interpreted.
    public enum WeekMode { case rolling7, calendarWeek }

    
    @inlinable
    func resolveHorizon(from args: PlanWeekArgs,
                        calendar calIn: Calendar = .autoupdatingCurrent,
                        timeZone tz: TimeZone = .current) -> (interval: DateInterval, timezone: TimeZone)
    {
        var cal = calIn
        cal.timeZone = tz

        // Start at local start-of-day for the provided date
        let start = cal.startOfDay(for: args.startDate)

        let days = (args.horizon?.lowercased() == "day") ? 1 : 7
        let end = cal.date(byAdding: .day, value: days, to: start) ?? start.addingTimeInterval(TimeInterval(days) * 24 * 60 * 60)

        return (DateInterval(start: start, end: end), tz)
    }

}

private func formatDecodingError(_ error: DecodingError) -> String {
    switch error {
    case .typeMismatch(let type, let context):
        return "Decoding error: type mismatch for \(type) at \(context.codingPath) – \(context.debugDescription)"
    case .valueNotFound(let type, let context):
        return "Decoding error: value not found for \(type) at \(context.codingPath) – \(context.debugDescription)"
    case .keyNotFound(let key, let context):
        return "Decoding error: key '\(key.stringValue)' not found – \(context.debugDescription)"
    case .dataCorrupted(let context):
        return "Decoding error: data corrupted – \(context.debugDescription)"
    @unknown default:
        return "Unknown decoding error"
    }
}


extension AIToolRouter {
    enum ToolTimeNormalizer {
        static func normalize(json: String, tzId: String, onlyKeys: Set<String>? = nil) throws -> String {
            let data = Data(json.utf8)
            let obj = try JSONSerialization.jsonObject(with: data, options: [])

            // Reuse your Swift port of ensureUtcArgs/toUtcIso
            let normalized = EnsureUTCHelper.ensureUtcArgs(obj, tzId: tzId, onlyKeys: onlyKeys)

            let out = try JSONSerialization.data(withJSONObject: normalized, options: [])
            guard let s = String(data: out, encoding: .utf8) else {
                throw NSError(domain: "ToolTimeNormalizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "UTF-8 encode failed"])
            }
            return s
        }
    }

    enum PayloadGuards {
        // Walk any Encodable payload and ensure all datetimes end with 'Z' (or are not date-like)
        static func assertUtcOnly<T: Encodable>(_ payload: T) throws {
            let data = try JSONEncoder().encode(payload)
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            var bad: [String] = []
            walk(obj, path: [], bad: &bad)
            if !bad.isEmpty {
                throw NSError(domain: "PayloadGuards", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Non-UTC datetimes in fields: \(bad.joined(separator: ", "))"
                ])
            }
        }

        private static func walk(_ v: Any, path: [String], bad: inout [String]) {
            switch v {
            case let s as String:
                // simple heuristic: looks like a datetime but not Z-terminated
                if s.range(of: #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}"#, options: .regularExpression) != nil &&
                   !s.hasSuffix("Z") &&
                   s.range(of: #"[+-]\d{2}:\d{2}$"#, options: .regularExpression) == nil {
                    bad.append(path.joined(separator: "."))
                }
            case let d as [String: Any]:
                for (k, vv) in d { walk(vv, path: path + [k], bad: &bad) }
            case let a as [Any]:
                for (i, vv) in a.enumerated() { walk(vv, path: path + ["[\(i)]"], bad: &bad) }
            default:
                break
            }
        }
    }

}
