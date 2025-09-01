//
//  Repo.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

// MARK: - Repository Protocols your app should conform to

import Foundation

public protocol TaskStore {
    @discardableResult
    func createTask(title: String, due: Date?, userInfo: [String: Any]?) async throws -> Any
    func tasks(dueIn range: Range<Date>) async throws -> [Any]
}

public protocol EventStore {
    associatedtype E: EventLike
    @discardableResult
    func createEvent(title: String, start: Date, end: Date, isRecurring: Bool) async throws -> E
    func updateEvent(id: UUID, start: Date, end: Date) async throws
    func events(in range: Range<Date>) async throws -> [E]
}
