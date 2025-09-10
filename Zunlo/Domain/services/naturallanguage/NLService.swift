//
//  NLService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/1/25.
//

import Foundation
import SmartParseKit
import LoggingKit

public protocol NLProcessing {
    func process(text: String) async throws -> [CommandResult]
}

public final class NLService: NLProcessing {
    private let parser: CommandParser
    private let tool: AIToolServiceAPI
    private let engine: IntentEngine
    
    public init(parser: CommandParser, tool: AIToolServiceAPI, engine: IntentEngine) {
        self.parser = parser
        self.tool = tool
        self.engine = engine
    }
    
    public func process(text: String) async throws -> [CommandResult] {
        var cal = Calendar.appDefault
        cal.timeZone = .current
        log("raw text: \(text), calendar: \(cal)")
        let language = engine.detectLanguage(text)
        log("language: \(language)")
        let splittedClauses = InputSplitter().split(text, language: language)
        log("splitted clauses: \(splittedClauses)")
        
        var results: [CommandResult] = []
        for clause in splittedClauses {
            let parsed = parser.parse(clause.text, now: Date(), calendar: cal)
            log("parsed command: \(parsed)")
            let result = try await tool
            let result = try await executor.execute(parsed, now: Date(), calendar: cal)
            log("command result: \(result)")
            results.append(result)
        }
        return results
    }
    
    public func execute(_ cmd: ParsedCommand, now: Date = Date(), calendar: Calendar = .current) async throws -> TaskMutationResult {
        switch cmd.intent {
        case .createTask:
            let input = TaskCreateInput(
                title: cmd.title ?? "New task",
                notes: nil,
                dueDate: cmd.when,
                isCompleted: false,
                tags: [],
                reminderTriggers: [],
                parentEventId: nil,
                priority: .medium
            )
            let wire = CreateTaskPayloadWire(idempotencyKey: UUID().uuidString, reason: "Tool exec", task: input)
            return try await tool.createTask(wire)
        case .createEvent:
            let input = EventCreateInput(
                title: cmd.title ?? "New event",
                startDatetime: cmd.when ?? cmd.dateRange?.lowerBound ?? Date(),
                endDatetime: cmd.end ?? cmd.dateRange?.upperBound,
                notes: nil,
                location: nil,
                color: .softOrange,
                reminderTriggers: nil,
                recurrenceRule: nil
            )
            let wire = CreateEventPayloadWire(idempotencyKey: UUID().uuidString, reason: "Tool exec", event: input)
            return try await tool.createEvent(wire)
        case .rescheduleEvent:  return try await handleRescheduleEvent(cmd)
        case .rescheduleTask:   return try await handleRescheduleTask(cmd)
        case .updateEvent:      return try await tool.updateEvent(<#T##payload: UpdateEventPayloadWire##UpdateEventPayloadWire#>)
        case .updateTask:       return try await tool.updateTask(<#T##payload: UpdateTaskPayloadWire##UpdateTaskPayloadWire#>)
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
}
