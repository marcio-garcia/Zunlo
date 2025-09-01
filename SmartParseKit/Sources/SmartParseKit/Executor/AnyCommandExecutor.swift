//
//  AnyCommandExecutor.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/1/25.
//

import Foundation

public protocol CommandExecuting {
    @discardableResult
    func execute(_ cmd: ParsedCommand,
                 now: Date,
                 calendar: Calendar) async throws -> CommandResult
}

public final class AnyCommandExecutor: CommandExecuting {
    private let _execute: (ParsedCommand, Date, Calendar) async throws -> CommandResult

    public init<ES: EventStore, TS: TaskStore>(_ base: CommandExecutor<ES, TS>) {
        self._execute = { cmd, now, cal in
            try await base.execute(cmd, now: now, calendar: cal)
        }
    }
    
    public convenience init<ES: EventStore, TS: TaskStore>(tasks: TS, events: ES) {
        self.init(CommandExecutor(tasks: tasks, events: events))
    }

    @discardableResult
    public func execute(_ cmd: ParsedCommand,
                        now: Date = Date(),
                        calendar: Calendar = .current) async throws -> CommandResult {
        try await _execute(cmd, now, calendar)
    }
}
