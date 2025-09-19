//
//  TaskStore.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/1/25.
//

import Foundation

// Minimal shape the executor needs to score/select tasks
public protocol TaskType {
    var id: UUID { get }
    var title: String { get }
    var dueDate: Date? { get }
}

// Replace your old TaskStore with this generic version
public protocol TaskStoreProtocol {
    associatedtype T: TaskType
    @discardableResult
    func createTask(title: String, due: Date?, userInfo: [String: Any]?) async throws -> T
    func tasks(dueIn range: Range<Date>) async throws -> [T]
    func allTasks() async throws -> [T]                 // for updates when dueDate is nil
    func updateTask(id: UUID, title: String?) async throws
    func rescheduleTask(id: UUID, due: Date) async throws
}
