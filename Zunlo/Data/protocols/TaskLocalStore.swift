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
    func fetchAll() async throws -> [UserTask]
    func fetchTasks(filteredBy filter: TaskFilter?) async throws -> [UserTask]
    func fetchAllUniqueTags() async throws -> [String]
    func apply(rows: [UserTaskRemote]) async throws
}
