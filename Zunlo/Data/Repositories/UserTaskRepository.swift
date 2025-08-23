//
//  UserTaskRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation
import MiniSignalEye

final public class UserTaskRepository {
    private let localStore: UserTaskLocalStore
    private let remoteStore: UserTaskRemoteStore
    private let reminderScheduler: ReminderScheduler<UserTask>
    private let calendar = Calendar.appDefault
    
//    var lastTaskAction = Observable<LastTaskAction>(.none)
    
    init(localStore: UserTaskLocalStore, remoteStore: UserTaskRemoteStore) {
        self.localStore = localStore
        self.remoteStore = remoteStore
        self.reminderScheduler = ReminderScheduler()
    }
    
    func upsert(_ task: UserTask) async throws {
        try await localStore.upsert(task)
        reminderScheduler.cancelReminders(for: task)
        reminderScheduler.scheduleReminders(for: task)
//        lastTaskAction.value = .update
    }
    
    func delete(_ task: UserTask) async throws {
        try await localStore.delete(id: task.id)
        reminderScheduler.cancelReminders(for: task)
//        lastTaskAction.value = .delete
    }
    
    func apply(rows: [UserTaskRemote]) async throws {
        try await localStore.apply(rows: rows)
    }

    @discardableResult
    func fetchTask(id: UUID) async throws -> UserTask? {
        guard let taskLocal = try await localStore.fetch(id: id) else {
            return nil
        }
        let task = UserTask(local: taskLocal)
//        lastTaskAction.value = .fetch([task])
        return task
    }
    
    @discardableResult
    func fetchAll() async throws -> [UserTask] {
        let tasks = try await localStore.fetchAll()
//        lastTaskAction.value = .fetch(tasks)
        return tasks
    }
    
    @discardableResult
    func fetchTasks(filteredBy filter: TaskFilter?) async throws -> [UserTask] {
        // Prefer local first, or merge with remote if needed
        let tasks = try await localStore.fetchTasks(filteredBy: filter)
//        lastTaskAction.value = .fetch(tasks)
        return tasks
    }
    
    @discardableResult
    func fetchAllUniqueTags() async throws -> [String] {
        let tags = try await localStore.fetchAllUniqueTags()
//        lastTaskAction.value = .fetchTags(tags)
        return tags
    }
}
