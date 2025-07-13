//
//  TaskRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation
import MiniSignalEye

final class UserTaskRepository {
    private let localStore: UserTaskLocalStore
    private let remoteStore: UserTaskRemoteStore

    private(set) var tasks = Observable<[UserTask]>([])

    init(localStore: UserTaskLocalStore, remoteStore: UserTaskRemoteStore) {
        self.localStore = localStore
        self.remoteStore = remoteStore
    }

    func fetchAll() async throws {
        let remoteTasks = try await remoteStore.fetchAll()
        try await localStore.deleteAll(for: remoteTasks.first?.user_id ?? UUID())
        for remote in remoteTasks {
            try await localStore.save(remote)
        }
        self.tasks.value = remoteTasks.map { $0.toDomain() }
    }

    func save(_ task: UserTask) async throws {
        let inserted = try await remoteStore.save(UserTaskRemote(domain: task))
        for task in inserted {
            try await localStore.save(task)
        }
        self.tasks.value = try await localStore.fetchAll()
    }

    func update(_ task: UserTask) async throws {
        let updated = try await remoteStore.update(UserTaskRemote(domain: task))
        for task in updated {
            try await localStore.update(task)
        }
        self.tasks.value = try await localStore.fetchAll()
    }

    func delete(_ task: UserTask) async throws {
        let deleted = try await remoteStore.delete(UserTaskRemote(domain: task))
        for task in deleted {
            if let id = task.id {
                try await localStore.delete(id: id)
            }
        }
        self.tasks.value = try await localStore.fetchAll()
    }
}
