//
//  CommandResult.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

public struct CommandResult: Sendable {
    public enum Outcome: Sendable { case createdTask, createdEvent, rescheduled, updated, planSuggestion, unknown }
    public var outcome: Outcome
    public var message: String
}
