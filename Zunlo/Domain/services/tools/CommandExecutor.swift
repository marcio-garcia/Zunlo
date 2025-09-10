//
//  CommandExecutor.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

import Foundation
import SmartParseKit

// Minimal shape the executor needs to score/select tasks
public protocol TaskType {
    var id: UUID { get }
    var title: String { get }
    var dueDate: Date? { get }
}

/// Conform your app's Event model to this to use SmartParseKit directly.
public protocol EventType {
    var id: UUID { get }
    var title: String { get }
    var startDate: Date { get }
    var endDate: Date { get }
    var isRecurring: Bool { get }
    var recurrenceType: String? { get }
    var recurrenceInterval: Int? { get }
    var byWeekday: [Int]? { get }
    var byMonthday: [Int]? { get }
    var until: Date? { get }
    var count: Int? { get }
}

public protocol AgendaType {
    var agenda: String { get }
    var attributedAgenda: AttributedString? { get }
}

public final class CommandExecutor {
    public let tasks: TaskStore
    public let events: EventStore
    
    public init(tasks: TaskStore, events: EventStore) {
        self.tasks = tasks
        self.events = events
    }
    
    @discardableResult
    public func execute(_ cmd: ParsedCommand, now: Date = Date(), calendar: Calendar = .current) async throws -> CommandResult {
        switch cmd.intent {
        case .createTask:       return try await handleCreateTask(cmd)
        case .createEvent:      return try await handleCreateEvent(cmd)
        case .rescheduleEvent:  return try await handleRescheduleEvent(cmd)
        case .rescheduleTask:   return try await handleRescheduleTask(cmd)
        case .updateEvent:      return try await handleUpdateEvent(cmd)
        case .updateTask:       return try await handleUpdateTask(cmd)
        case .planWeek, .planDay:
            return try await handlePlanning(cmd, now: now, calendar: calendar)
        case .showAgenda:
            return try await handleShowAgenda(cmd, now: now, calendar: calendar)
        case .moreInfo:
            return CommandResult(outcome: .moreInfo, message: "Need more info.")
        case .unknown:
            return CommandResult(outcome: .unknown, message: "I couldn’t understand. Try ‘create task …’, ‘create event …’, or ‘reschedule …’.")
        }
    }
    
    private func handleCreateTask(_ c: ParsedCommand) async throws -> CommandResult {
        let title = c.title ?? "Untitled task"
        guard let task = tasks.makeTask(title: title, dueDate: c.when) else {
            return .init(outcome: .unknown, message: "I couldn’t handle task properly.")
        }
        _ = try await tasks.upsert(task)
        let whenStr = c.when.map { DateFormatter.short(date: $0) } ?? nil
        return CommandResult(outcome: .createdTask, message: whenStr == nil ? "Task ‘\(title)’ created." : "Task ‘\(title)’ created for \(whenStr!).")
    }
    
    private func handleCreateEvent(_ c: ParsedCommand) async throws -> CommandResult {
        let title = c.title ?? "New event"
        let start = c.when ?? Date()
        let end = c.end ?? c.dateRange?.upperBound ?? start.addingTimeInterval(30*60)
        guard let event = events.makeEvent(title: title, start: start, end: end) else {
            return .init(outcome: .unknown, message: "I couldn’t handle event properly.")
        }
        _ = try await events.upsert(event)
        return CommandResult(outcome: .createdEvent, message: "Event ‘\(title)’ scheduled at \(DateFormatter.short(dateTime: start)).")
    }
    
    private func handleRescheduleEvent(_ c: ParsedCommand) async throws -> CommandResult {
        let hints = RescheduleHints(preferredDate: c.when, keywords: tokenizeKeywords(c.title ?? "meeting"))
        let window = candidateWindow(for: hints)
        let todays = try await events.fetchOccurrences(in: window)
        var target = selectEventToReschedule(events: todays, hints: hints)

        if target == nil {
            let start = Calendar.current.date(byAdding: .day, value: -2, to: window.lowerBound)!
            let end   = Calendar.current.date(byAdding: .day, value:  3, to: window.upperBound)!
            let wider = try? await events.fetchOccurrences(in: start..<end)
            target = wider.flatMap { selectEventToReschedule(events: $0, hints: hints) }
        }
        guard let event = target else {
            return .init(outcome: .unknown, message: "I couldn’t find a matching event to move.")
        }
        guard let newTime = c.newTime ?? c.when else {
            return .init(outcome: .unknown, message: "Tell me the new time, e.g., ‘reschedule \(c.title ?? "meeting") to 2pm’.")
        }
        let duration = event.endDate.timeIntervalSince(event.startDate)
        guard var orig = try await events.fetchEvent(by: event.id) else {
            return .init(outcome: .unknown, message: "I couldn’t handle event properly.")
        }
        orig.startDate = newTime
        orig.endDate = newTime.addingTimeInterval(duration ?? 0)
        try await events.upsert(orig)
        return CommandResult(outcome: .rescheduled, message: "‘\(event.title)’ moved to \(DateFormatter.short(dateTime: newTime)).")
    }

    private func handleRescheduleTask(_ c: ParsedCommand) async throws -> CommandResult {
        guard let newDue = c.newTime ?? c.when else {
            return CommandResult(outcome: .unknown, message: "Tell me the new due date/time, e.g., ‘reschedule the pay rent task to Friday’")
        }
        let hintWords = tokenizeKeywords(c.title ?? "")
        let all = try await tasks.fetchAll()
        guard var target = selectTaskToUpdate(all, keywords: hintWords) else {
            return CommandResult(outcome: .unknown, message: "I couldn’t find a matching task to move.")
        }
        target.dueDate = newDue
        try await tasks.upsert(target)
        return CommandResult(outcome: .rescheduled, message: "Task ‘\(target.title)’ due \(DateFormatter.short(date: newDue)).")
    }

    private func handleUpdateTask(_ c: ParsedCommand) async throws -> CommandResult {
        let (oldHint, newTitle) = parseRenameHints(c.raw)
        guard let newTitle = newTitle ?? c.title else {
            return CommandResult(outcome: .unknown, message: "Tell me the new task title, e.g., ‘rename task buy cat food to buy dog food’.")
        }

        let candidates = try await tasks.fetchAll()
        var target = selectTaskToUpdate(candidates, keywords: tokenizeKeywords(oldHint ?? c.title ?? "")) ?? candidates.first
        guard var t = target else { return .init(outcome: .unknown, message: "I couldn’t find which task to update.") }
        t.title = newTitle
        try await tasks.upsert(t)
        return CommandResult(outcome: .updated, message: "Task ‘\(t.title)’ renamed to ‘\(newTitle)’.")
    }

    private func handleUpdateEvent(_ c: ParsedCommand) async throws -> CommandResult {
        let (oldHint, newTitle) = parseRenameHints(c.raw)
        guard let newTitle = newTitle ?? c.title else {
            return CommandResult(outcome: .unknown, message: "Tell me the new event title, e.g., ‘rename the meeting to Product Sync’.")
        }

        // Find a candidate event around today (or use c.when if present for better narrowing)
        let base = c.when ?? Date()
        let day = candidateWindow(for: .init(preferredDate: base, keywords: tokenizeKeywords(oldHint ?? "")))
        let todays = try await events.fetchOccurrences(in: day)
        let target = selectEventToReschedule(events: todays, hints: .init(preferredDate: base, keywords: tokenizeKeywords(oldHint ?? ""))) ?? todays.first

        guard let e = target else { return .init(outcome: .unknown, message: "I couldn’t find which event to update.") }

//        try await events.updateEventMetadata(id: e.id, newTitle: newTitle)
        // TODO: Check if override or event and save accordingly
        return CommandResult(outcome: .updated, message: "Event ‘\(e.title)’ renamed to ‘\(newTitle)’.")
    }

    private func handlePlanning(_ c: ParsedCommand, now: Date, calendar: Calendar) async throws -> CommandResult {
        let range: Range<Date> = {
            if let r = c.dateRange { return r }
            if c.intent == .planDay || c.intent == .showAgenda {
                let start = calendar.startOfDay(for: now)
                return start..<(calendar.date(byAdding: .day, value: 1, to: start)!)
            }
            return weekRange(containing: now, calendar: calendar)
        }()
//        let es = try await events.events(in: range)
        // TODO: Create plan
//        let msg = "Here’s your plan for \(DateFormatter.compact(date: range.lowerBound))–\(DateFormatter.compact(date: range.upperBound.addingTimeInterval(-60))): • \(es.count) events"
//        return CommandResult(outcome: .planSuggestion, message: msg)
        return CommandResult(outcome: .planSuggestion, message: "")
    }

    private func handleShowAgenda(_ c: ParsedCommand, now: Date, calendar: Calendar) async throws -> CommandResult {
        var range: Range<Date>
        if let r = c.dateRange {
            range = r
        } else {
            range = {
                if let r = c.dateRange { return r }
                if c.intent == .planDay || c.intent == .showAgenda {
                    let start = calendar.startOfDay(for: now)
                    return start..<(calendar.date(byAdding: .day, value: 1, to: start)!)
                }
                return weekRange(containing: now, calendar: calendar)
            }()
        }
        let agenda = try await agenda(in: range)
//        let msg = "Here’s your plan for \(DateFormatter.compact(date: range.lowerBound))–\(DateFormatter.compact(date: range.upperBound.addingTimeInterval(-60))): • \(es.count) events"
        return CommandResult(outcome: .agenda, message: agenda.note, attributedString: agenda.attributedText)
    }
    
    // MARK: Helpers
    
    private func agenda(in range: Range<Date>) async throws -> ToolDispatchResult {
        var agendaRange: GetAgendaArgs.DateRange = .custom
        let today = Date().startOfDay()
        let tomorrow = today.startOfNextDay()
        let afterTomorrow = tomorrow.startOfNextDay()
        
        if range == today..<tomorrow {
            agendaRange = .today
        } else if range == tomorrow..<afterTomorrow {
            agendaRange = .tomorrow
        } else if range.lowerBound.daysInterval(to: range.upperBound) == 7 {
            agendaRange = .week
        }
        
        let agendaArgs = GetAgendaArgs(dateRange: agendaRange, start: range.lowerBound, end: range.upperBound)
        
        do {
            let args = try JSONEncoder.makeEncoder().encode(agendaArgs)
            if let argsJSON = String(data: args, encoding: .utf8) {
                let toolEnvelope = AIToolEnvelope(name: "getAgenda", argsJSON: argsJSON)
//                let result = try await aiToolRouter.dispatch(toolEnvelope)
//                return result
                return ToolDispatchResult(note: "")
            }
        } catch {
            print(error)
        }
        return ToolDispatchResult(note: "")
    }
    
    // Simple task scorer mirroring your event ranking
    private func selectTaskToUpdate<T: TaskType>(_ tasks: [T], keywords: [String]) -> T? {
        guard !tasks.isEmpty else { return nil }
        let ranked = tasks.map { t -> (T, Double) in
            var score = 0.0
            let title = t.title.lowercased()
            for kw in keywords where !kw.isEmpty { if title.contains(kw) { score += 0.6 } }
            // prefer tasks with a due date soon (optional)
            if let due = t.dueDate {
                let delta = abs(due.timeIntervalSinceNow)
                score += max(0, 0.5 - min(delta / (7*24*3600), 0.5)) // up to +0.5 if due within ~a week
            }
            return (t, score)
        }.sorted { $0.1 > $1.1 }
        return ranked.first?.0
    }

    // Extract (“old”, “new”) from rename phrases in EN/PT-BR
    private func parseRenameHints(_ s: String) -> (old: String?, new: String?) {
        let lower = s.lowercased()

        // EN: rename ... to NEW
        if let m = try? NSRegularExpression(pattern: #"rename(?:\s+(?:the\s+)?)?(?:task|event|meeting)?\s*(.+?)\s+to\s+(.+)"#, options: .caseInsensitive),
           let mm = m.firstMatch(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower)) {
            let old = Range(mm.range(at: 1), in: lower).map { String(lower[$0]).trimmingCharacters(in: .whitespaces) }
            let new = Range(mm.range(at: 2), in: lower).map { String(lower[$0]).trimmingCharacters(in: .whitespaces) }
            return (old, new)
        }

        // EN: update ... title to NEW
        if let m = try? NSRegularExpression(pattern: #"update\s+(?:task|event|meeting)\s+title\s+to\s+(.+)"#, options: .caseInsensitive),
           let mm = m.firstMatch(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower)) {
            let new = Range(mm.range(at: 1), in: lower).map { String(lower[$0]).trimmingCharacters(in: .whitespaces) }
            return (nil, new)
        }

        // PT-BR: renomear ... para NOVO
        if let m = try? NSRegularExpression(pattern: #"renomear\s+(?:a\s+)?(?:tarefa|evento|reuni[aã]o)?\s*(.+?)\s+para\s+(.+)"#, options: .caseInsensitive),
           let mm = m.firstMatch(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower)) {
            let old = Range(mm.range(at: 1), in: lower).map { String(lower[$0]).trimmingCharacters(in: .whitespaces) }
            let new = Range(mm.range(at: 2), in: lower).map { String(lower[$0]).trimmingCharacters(in: .whitespaces) }
            return (old, new)
        }

        // PT-BR: atualizar título ... para NOVO
        if let m = try? NSRegularExpression(pattern: #"atualizar\s+t[ií]tulo\s+(?:da\s+tarefa|do\s+evento)?\s*para\s+(.+)"#, options: .caseInsensitive),
           let mm = m.firstMatch(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower)) {
            let new = Range(mm.range(at: 1), in: lower).map { String(lower[$0]).trimmingCharacters(in: .whitespaces) }
            return (nil, new)
        }

        return (nil, nil)
    }
    
    private func tokenizeKeywords(_ s: String) -> [String] {
        s.lowercased()
            .replacingOccurrences(of: "[^a-zA-ZÀ-ÿ0-9 ]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 }
    }

    private func candidateWindow(for hints: RescheduleHints, calendar: Calendar = .current) -> Range<Date> {
        let base = hints.preferredDate ?? Date()
        let start = calendar.startOfDay(for: base)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return start..<end
    }
    
    @inline(__always)
    private func weekRange(containing date: Date, calendar: Calendar = .current) -> Range<Date> {
        var start = Date()
        var interval: TimeInterval = 0
        _ = calendar.dateInterval(of: .weekOfYear, start: &start, interval: &interval, for: date)
        return start..<(start.addingTimeInterval(interval))
    }
}

extension DateFormatter {
    static func short(date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: date)
    }
    static func short(dateTime: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: dateTime)
    }
    static func compact(date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
