//
//  TaskRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation

protocol UserTaskRemoteStore {
    func fetchAll() async throws -> [UserTaskRemote]
    func save(_ task: UserTaskRemote) async throws -> [UserTaskRemote]
    func update(_ task: UserTaskRemote) async throws -> [UserTaskRemote]
    func delete(_ id: UUID) async throws -> [UserTaskRemote]
    func deleteAll(for userId: UUID) async throws -> [UserTaskRemote]
}
