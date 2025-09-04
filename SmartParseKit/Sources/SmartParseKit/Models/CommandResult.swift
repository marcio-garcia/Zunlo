//
//  CommandResult.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

import Foundation

public struct CommandResult: Sendable {
    public enum Outcome: Sendable {
        case createdTask, createdEvent
        case rescheduled, updated
        case planSuggestion
        case agenda
        case unknown
    }
    
    public var outcome: Outcome
    public var message: String
    public var attributedString: AttributedString?
    
    public init(outcome: CommandResult.Outcome, message: String, attributedString: AttributedString? = nil) {
        self.outcome = outcome
        self.message = message
        self.attributedString = attributedString
    }
}
