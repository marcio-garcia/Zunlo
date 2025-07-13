//
//  TaskLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation

protocol UserTaskLocalStore {
    func fetchAll() async throws -> [UserTask]
    func save(_ remoteTask: UserTaskRemote) async throws
    func update(_ task: UserTaskRemote) async throws
    func delete(id: UUID) async throws
    func deleteAll(for userId: UUID) async throws
}
