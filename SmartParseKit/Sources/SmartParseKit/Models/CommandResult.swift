//
//  CommandResult.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

public struct CommandResult {
    public enum Outcome { case createdTask, createdEvent, rescheduled, planSuggestion, unknown }
    public var outcome: Outcome
    public var message: String
}
