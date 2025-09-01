//
//  CommandExecutor.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

// Sources/SmartParseKit/SmartParseKit.swift
// Entry point + key components for SmartParseKit

import Foundation
import NaturalLanguage

public final class CommandExecutor<ES: EventStore> {
    public let tasks: TaskStore
    public let events: ES

    public init(tasks: TaskStore, events: ES) {
        self.tasks = tasks
        self.events = events
    }

    @discardableResult
    public func execute(_ cmd: ParsedCommand, now: Date = Date(), calendar: Calendar = .current) async throws -> CommandResult {
        switch cmd.intent {
        case .createTask:
            return try await handleCreateTask(cmd)
        case .createEvent:
            return try await handleCreateEvent(cmd)
        case .updateReschedule:
            return try await handleReschedule(cmd)
        case .planWeek, .planDay, .showAgenda:
            return try await handlePlanning(cmd, now: now, calendar: calendar)
        case .unknown:
            return .init(outcome: .unknown, message: "I couldn’t understand. Try ‘create task …’, ‘create event …’, or ‘reschedule …’.")
        }
    }

    private func handleCreateTask(_ c: ParsedCommand) async throws -> CommandResult {
        let title = c.title ?? "Untitled task"
        _ = try await tasks.createTask(title: title, due: c.when, userInfo: nil)
        let whenStr = c.when.map { DateFormatter.short(date: $0) } ?? nil
        return .init(outcome: .createdTask, message: whenStr == nil ? "Task ‘\(title)’ created." : "Task ‘\(title)’ created for \(whenStr!).")
    }

    private func handleCreateEvent(_ c: ParsedCommand) async throws -> CommandResult {
        let title = c.title ?? "New event"
        let start = c.when ?? Date()
        let end = c.end ?? start.addingTimeInterval(30*60)
        _ = try await events.createEvent(title: title, start: start, end: end, isRecurring: false)
        return .init(outcome: .createdEvent, message: "Event ‘\(title)’ scheduled at \(DateFormatter.short(dateTime: start)).")
    }

    private func handleReschedule(_ c: ParsedCommand) async throws -> CommandResult {
        let hints = RescheduleHints(preferredDate: c.when, keywords: tokenizeKeywords(c.title ?? "meeting"))
        let window = candidateWindow(for: hints)
        let todays = try await events.events(in: window)
        var target = selectEventToReschedule(events: todays, hints: hints)
        if target == nil {
            let start = Calendar.current.date(byAdding: .day, value: -2, to: window.lowerBound)!
            let end = Calendar.current.date(byAdding: .day, value: 3, to: window.upperBound)!
            let wider = try? await events.events(in: start..<end)
            target = wider.flatMap { selectEventToReschedule(events: $0, hints: hints) }
        }
        guard let event = target else {
            return .init(outcome: .unknown, message: "I couldn’t find a matching event to move.")
        }
        guard let newTime = c.newTime ?? c.when else {
            return .init(outcome: .unknown, message: "Tell me the new time, e.g., ‘reschedule \(c.title ?? "meeting") to 2pm’.")
        }
        let duration = (event.endDate ?? event.startDate.addingTimeInterval(30*60)).timeIntervalSince(event.startDate)
        try await events.updateEvent(id: event.id, start: newTime, end: newTime.addingTimeInterval(duration))
        return .init(outcome: .rescheduled, message: "‘\(event.title)’ moved to \(DateFormatter.short(dateTime: newTime)).")
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
        return .init(outcome: .planSuggestion, message: msg)
    }
}

// MARK: - Helpers used by executor

func tokenizeKeywords(_ s: String) -> [String] {
    s.lowercased()
        .replacingOccurrences(of: "[^a-zA-ZÀ-ÿ0-9 ]", with: " ", options: .regularExpression)
        .split(separator: " ")
        .map(String.init)
        .filter { $0.count > 2 }
}

public func candidateWindow(for hints: RescheduleHints, calendar: Calendar = .current) -> Range<Date> {
    let base = hints.preferredDate ?? Date()
    let start = calendar.startOfDay(for: base)
    let end = calendar.date(byAdding: .day, value: 1, to: start)!
    return start..<end
}

// MARK: - Pretty date formatting

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

