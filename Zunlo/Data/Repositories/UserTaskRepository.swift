//
//  UserTaskRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation

final public class UserTaskRepository {
    private let auth: AuthProviding
    private let localStore: UserTaskLocalStore
    private let remoteStore: UserTaskRemoteStore
    private let reminderScheduler: ReminderScheduler<UserTask>
    private let calendar = Calendar.appDefault
    
    init(
        auth: AuthProviding,
        localStore: UserTaskLocalStore,
        remoteStore: UserTaskRemoteStore
    ) {
        self.auth = auth
        self.localStore = localStore
        self.remoteStore = remoteStore
        self.reminderScheduler = ReminderScheduler()
    }
    
    func upsert(_ task: UserTask) async throws {
        guard await auth.isAuthorized(), let _ = auth.userId else { return }
        try await localStore.upsert(task)
        reminderScheduler.cancelReminders(for: task)
        reminderScheduler.scheduleReminders(for: task)
    }
    
    func delete(_ task: UserTask) async throws {
        guard await auth.isAuthorized(), let userId = auth.userId else { return }
        try await localStore.delete(id: task.id, userId: userId)
        reminderScheduler.cancelReminders(for: task)
    }
    
    func apply(rows: [UserTaskRemote]) async throws {
        guard await auth.isAuthorized(), let _ = auth.userId else { return }
        try await localStore.apply(rows: rows)
    }

    @discardableResult
    func fetchTask(id: UUID) async throws -> UserTask? {
        guard let taskLocal = try await localStore.fetch(id: id) else {
            return nil
        }
        let task = UserTask(local: taskLocal)
        return task
    }
    
    @discardableResult
    func fetchAll() async throws -> [UserTask] {
        let tasks = try await localStore.fetchAll()
        return tasks
    }
    
    @discardableResult
    func fetchTasks(filteredBy filter: TaskFilter?) async throws -> [UserTask] {
        // Prefer local first, or merge with remote if needed
        let tasks = try await localStore.fetchTasks(filteredBy: filter)
        return tasks
    }
    
    @discardableResult
    func fetchAllUniqueTags() async throws -> [String] {
        let tags = try await localStore.fetchAllUniqueTags()
        return tags
    }
}
