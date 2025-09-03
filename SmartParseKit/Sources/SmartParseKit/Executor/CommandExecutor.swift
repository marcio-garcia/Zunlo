//
//  CommandExecutor.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

import Foundation
import NaturalLanguage

public final class CommandExecutor<ES: EventStore, TS: TaskStore> {
    public let tasks: TS
    public let events: ES
    
    public init(tasks: TS, events: ES) {
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
        case .unknown:
            return CommandResult(outcome: .unknown, message: "I couldn’t understand. Try ‘create task …’, ‘create event …’, or ‘reschedule …’.")
        }
    }
    
    private func handleCreateTask(_ c: ParsedCommand) async throws -> CommandResult {
        let title = c.title ?? "Untitled task"
        _ = try await tasks.createTask(title: title, due: c.when, userInfo: nil)
        let whenStr = c.when.map { DateFormatter.short(date: $0) } ?? nil
        return CommandResult(outcome: .createdTask, message: whenStr == nil ? "Task ‘\(title)’ created." : "Task ‘\(title)’ created for \(whenStr!).")
    }
    
    private func handleCreateEvent(_ c: ParsedCommand) async throws -> CommandResult {
        let title = c.title ?? "New event"
        let start = c.when ?? Date()
        let end = c.end ?? start.addingTimeInterval(30*60)
        _ = try await events.createEvent(title: title, start: start, end: end, isRecurring: false)
        return CommandResult(outcome: .createdEvent, message: "Event ‘\(title)’ scheduled at \(DateFormatter.short(dateTime: start)).")
    }
    
    private func handleRescheduleEvent(_ c: ParsedCommand) async throws -> CommandResult {
        let hints = RescheduleHints(preferredDate: c.when, keywords: tokenizeKeywords(c.title ?? "meeting"))
        let window = candidateWindow(for: hints)
        let todays = try await events.events(in: window)
        var target = selectEventToReschedule(events: todays, hints: hints)

        if target == nil {
            let start = Calendar.current.date(byAdding: .day, value: -2, to: window.lowerBound)!
            let end   = Calendar.current.date(byAdding: .day, value:  3, to: window.upperBound)!
            let wider = try? await events.events(in: start..<end)
            target = wider.flatMap { selectEventToReschedule(events: $0, hints: hints) }
        }
        guard let event = target else {
            return .init(outcome: .unknown, message: "I couldn’t find a matching event to move.")
        }
        guard let newTime = c.newTime ?? c.when else {
            return .init(outcome: .unknown, message: "Tell me the new time, e.g., ‘reschedule \(c.title ?? "meeting") to 2pm’.")
        }
        let duration = event.endDate.timeIntervalSince(event.startDate)
        try await events.updateEvent(id: event.id, start: newTime, end: newTime.addingTimeInterval(duration))
        return CommandResult(outcome: .rescheduled, message: "‘\(event.title)’ moved to \(DateFormatter.short(dateTime: newTime)).")
    }

    private func handleRescheduleTask(_ c: ParsedCommand) async throws -> CommandResult {
        guard let newDue = c.newTime ?? c.when else {
            return CommandResult(outcome: .unknown, message: "Tell me the new due date/time, e.g., ‘reschedule the pay rent task to Friday’")
        }
        let hintWords = tokenizeKeywords(c.title ?? "")
        let all = try await tasks.allTasks()
        guard let target = selectTaskToUpdate(all, keywords: hintWords) else {
            return CommandResult(outcome: .unknown, message: "I couldn’t find a matching task to move.")
        }
        try await tasks.rescheduleTask(id: target.id, due: newDue)
        return CommandResult(outcome: .rescheduled, message: "Task ‘\(target.title)’ due \(DateFormatter.short(date: newDue)).")
    }

    private func handleUpdateTask(_ c: ParsedCommand) async throws -> CommandResult {
        let (oldHint, newTitle) = parseRenameHints(c.raw)
        guard let newTitle = newTitle ?? c.title else {
            return CommandResult(outcome: .unknown, message: "Tell me the new task title, e.g., ‘rename task buy cat food to buy dog food’.")
        }

        let candidates = try await tasks.allTasks()
        let target = selectTaskToUpdate(candidates, keywords: tokenizeKeywords(oldHint ?? c.title ?? "")) ?? candidates.first
        guard let t = target else { return .init(outcome: .unknown, message: "I couldn’t find which task to update.") }

        try await tasks.updateTask(id: t.id, title: newTitle)
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
        let todays = try await events.events(in: day)
        let target = selectEventToReschedule(events: todays, hints: .init(preferredDate: base, keywords: tokenizeKeywords(oldHint ?? ""))) ?? todays.first

        guard let e = target else { return .init(outcome: .unknown, message: "I couldn’t find which event to update.") }

        try await events.updateEventMetadata(id: e.id, newTitle: newTitle)
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
        let es = try await events.events(in: range)
        let msg = "Here’s your plan for \(DateFormatter.compact(date: range.lowerBound))–\(DateFormatter.compact(date: range.upperBound.addingTimeInterval(-60))): • \(es.count) events"
        return CommandResult(outcome: .planSuggestion, message: msg)
    }

    private func handleShowAgenda(_ c: ParsedCommand, now: Date, calendar: Calendar) async throws -> CommandResult {
        let range: Range<Date> = {
            if let r = c.dateRange { return r }
            if c.intent == .planDay || c.intent == .showAgenda {
                let start = calendar.startOfDay(for: now)
                return start..<(calendar.date(byAdding: .day, value: 1, to: start)!)
            }
            return weekRange(containing: now, calendar: calendar)
        }()
        let agenda = try await events.agenda(in: range)
//        let msg = "Here’s your plan for \(DateFormatter.compact(date: range.lowerBound))–\(DateFormatter.compact(date: range.upperBound.addingTimeInterval(-60))): • \(es.count) events"
        return CommandResult(outcome: .agenda, message: agenda.agenda, attributedString: agenda.attributedAgenda)
    }
    
    // MARK: Helpers
    
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

//public final class CommandExecutor<ES: EventStore> {
//    public let tasks: TaskStore
//    public let events: ES
//
//    public init(tasks: TaskStore, events: ES) {
//        self.tasks = tasks
//        self.events = events
//    }
//
//    @discardableResult
//    public func execute(_ cmd: ParsedCommand, now: Date = Date(), calendar: Calendar = .current) async throws -> CommandResult {
//        switch cmd.intent {
//        case .createTask:
//            return try await handleCreateTask(cmd)
//        case .createEvent:
//            return try await handleCreateEvent(cmd)
//        case .updateReschedule:
//            return try await handleReschedule(cmd)
//        case .planWeek, .planDay, .showAgenda:
//            return try await handlePlanning(cmd, now: now, calendar: calendar)
//        case .unknown:
//            return .init(outcome: .unknown, message: "I couldn’t understand. Try ‘create task …’, ‘create event …’, or ‘reschedule …’.")
//        }
//    }
//
//    private func handleCreateTask(_ c: ParsedCommand) async throws -> CommandResult {
//        let title = c.title ?? "Untitled task"
//        _ = try await tasks.createTask(title: title, due: c.when, userInfo: nil)
//        let whenStr = c.when.map { DateFormatter.short(date: $0) } ?? nil
//        return .init(outcome: .createdTask, message: whenStr == nil ? "Task ‘\(title)’ created." : "Task ‘\(title)’ created for \(whenStr!).")
//    }
//
//    private func handleCreateEvent(_ c: ParsedCommand) async throws -> CommandResult {
//        let title = c.title ?? "New event"
//        let start = c.when ?? Date()
//        let end = c.end ?? start.addingTimeInterval(30*60)
//        _ = try await events.createEvent(title: title, start: start, end: end, isRecurring: false)
//        return .init(outcome: .createdEvent, message: "Event ‘\(title)’ scheduled at \(DateFormatter.short(dateTime: start)).")
//    }
//
//    private func handleReschedule(_ c: ParsedCommand) async throws -> CommandResult {
//        let hints = RescheduleHints(preferredDate: c.when, keywords: tokenizeKeywords(c.title ?? "meeting"))
//        let window = candidateWindow(for: hints)
//        let todays = try await events.events(in: window)
//        var target = selectEventToReschedule(events: todays, hints: hints)
//        if target == nil {
//            let start = Calendar.current.date(byAdding: .day, value: -2, to: window.lowerBound)!
//            let end = Calendar.current.date(byAdding: .day, value: 3, to: window.upperBound)!
//            let wider = try? await events.events(in: start..<end)
//            target = wider.flatMap { selectEventToReschedule(events: $0, hints: hints) }
//        }
//        guard let event = target else {
//            return .init(outcome: .unknown, message: "I couldn’t find a matching event to move.")
//        }
//        guard let newTime = c.newTime ?? c.when else {
//            return .init(outcome: .unknown, message: "Tell me the new time, e.g., ‘reschedule \(c.title ?? "meeting") to 2pm’.")
//        }
//        let duration = event.endDate.timeIntervalSince(event.startDate)
//        try await events.updateEvent(id: event.id, start: newTime, end: newTime.addingTimeInterval(duration))
//        return .init(outcome: .rescheduled, message: "‘\(event.title)’ moved to \(DateFormatter.short(dateTime: newTime)).")
//    }
//
//    private func handlePlanning(_ c: ParsedCommand, now: Date, calendar: Calendar) async throws -> CommandResult {
//        let range: Range<Date> = {
//            if let r = c.dateRange { return r }
//            if c.intent == .planDay || c.intent == .showAgenda {
//                let start = calendar.startOfDay(for: now)
//                return start..<(calendar.date(byAdding: .day, value: 1, to: start)!)
//            }
//            return weekRange(containing: now, calendar: calendar)
//        }()
//        let es = try await events.events(in: range)
//        let msg = "Here’s your plan for \(DateFormatter.compact(date: range.lowerBound))–\(DateFormatter.compact(date: range.upperBound.addingTimeInterval(-60))): • \(es.count) events"
//        return .init(outcome: .planSuggestion, message: msg)
//    }
//}
//
