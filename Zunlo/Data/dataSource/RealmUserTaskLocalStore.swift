//
//  RealmUserTaskLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation
import RealmSwift

final class RealmUserTaskLocalStore: UserTaskLocalStore {
    private let db: DatabaseActor
    init(db: DatabaseActor) { self.db = db }

    func upsert(_ remote: UserTaskRemote) async throws {
        try await db.upsertUserTask(from: remote)
    }
    
    func upsert(_ domain: UserTask) async throws {
        try await db.upsertUserTask(from: domain)
    }

    func delete(id: UUID) async throws {
        try await db.deleteUserTask(id: id)
    }

    func fetch(id: UUID) async throws -> UserTaskLocal? {
        try await db.fetchTask(id: id)
    }
    
    func fetchAll() async throws -> [UserTask] {
        try await db.fetchAllUserTasks()
    }

    func fetchTasks(filteredBy filter: TaskFilter? = nil) async throws -> [UserTask] {
        try await db.fetchUserTasks(filteredBy: filter)
    }

    func fetchAllUniqueTags() async throws -> [String] {
        try await db.fetchAllUniqueTaskTags()
    }
    
    func apply(rows: [UserTaskRemote]) async throws {
        try await db.applyRemoteUserTasks(rows)
    }
}
