//
//  UserTaskRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation
import MiniSignalEye

final class UserTaskRepository {
    private let localStore: UserTaskLocalStore
    private let remoteStore: UserTaskRemoteStore
    private let reminderScheduler: ReminderScheduler<UserTask>
    
    private(set) var tasks = Observable<[UserTask]>([])

    init(localStore: UserTaskLocalStore, remoteStore: UserTaskRemoteStore) {
        self.localStore = localStore
        self.remoteStore = remoteStore
        self.reminderScheduler = ReminderScheduler()
    }

    func save(_ task: UserTask) async throws {
        let savedRemote = try await remoteStore.save(UserTaskRemote(domain: task))
        for remote in savedRemote {
            try await localStore.save(remote)
            let domain = UserTask(remote: remote)
            reminderScheduler.scheduleReminders(for: domain)
        }
        self.tasks.value = try await localStore.fetchAll()
    }

    func update(_ task: UserTask) async throws {
        let updatedRemote = try await remoteStore.update(UserTaskRemote(domain: task))
        for remote in updatedRemote {
            try await localStore.update(remote)
            let domain = UserTask(remote: remote)
            reminderScheduler.cancelReminders(for: domain)
            reminderScheduler.scheduleReminders(for: domain)
        }
        self.tasks.value = try await localStore.fetchAll()
    }

    func delete(_ task: UserTask) async throws {
        guard let id = task.id else { return }
        let deleted = try await remoteStore.delete(id)
        for task in deleted {
            if let id = task.id {
                try await localStore.delete(id: id)
            }
        }
        reminderScheduler.cancelReminders(for: task)
        self.tasks.value = try await localStore.fetchAll()
    }
    
    func fetchAll() async throws {
        let remoteTasks = try await remoteStore.fetchAll()
        try await localStore.deleteAll(for: remoteTasks.first?.userId ?? UUID())
        for remote in remoteTasks {
            try await localStore.save(remote)
        }
        self.tasks.value = remoteTasks.map { $0.toDomain() }
    }
    
    func fetchTasks(filteredBy filter: TaskFilter?) async throws {
        // Prefer local first, or merge with remote if needed
        let localTasks = try await localStore.fetchTasks(filteredBy: filter)
        self.tasks.value = localTasks
    }
    
    func fetchAllUniqueTags() async throws -> [String] {
        try await localStore.fetchAllUniqueTags()
    }
}
