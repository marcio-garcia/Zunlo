//
//  TaskLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation

protocol UserTaskLocalStore {
    func upsert(_ remote: UserTaskRemote) async throws
    func upsert(_ domain: UserTask) async throws
    func delete(id: UUID, userId: UUID) async throws
    func fetch(id: UUID) async throws -> UserTaskLocal?
    func fetchAll(userId: UUID) async throws -> [UserTask]
    func fetchTasks(filteredBy filter: TaskFilter?, userId: UUID) async throws -> [UserTask]
    func fetchAllUniqueTags(userId: UUID) async throws -> [String]
    func apply(rows: [UserTaskRemote]) async throws
}
