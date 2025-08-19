//
//  AIToolAPI.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation

public protocol AIToolServiceAPI: Sendable {
    // MARK: - Tasks
    @discardableResult
    func createTask(_ payload: CreateTaskPayloadWire) async throws -> TaskMutationResult
    @discardableResult
    func updateTask(_ payload: UpdateTaskPayloadWire) async throws -> TaskMutationResult
    @discardableResult
    func deleteTask(_ payload: DeleteTaskPayloadWire) async throws -> TaskMutationResult
    // MARK: - Events
    @discardableResult
    func createEvent(_ payload: CreateEventPayloadWire) async throws -> EventMutationResult
    @discardableResult
    func updateEvent(_ payload: UpdateEventPayloadWire) async throws -> EventMutationResult
    @discardableResult
    func deleteEvent(_ payload: DeleteEventPayloadWire) async throws -> EventMutationResult
}
