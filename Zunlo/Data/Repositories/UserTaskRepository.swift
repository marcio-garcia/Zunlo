//
//  UserTaskRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation

protocol TaskStore {
//    func makeTask(title: String, dueDate: Date?) -> UserTask?
    func fetchAll() async throws -> [UserTask]
    func fetchTasks(filteredBy filter: TaskFilter?) async throws -> [UserTask]
    func upsert(_ task: UserTask) async throws
    func update(id: UUID, due: Date?) async throws
    func insert(title: String, due: Date?) async throws -> UUID
}

final class UserTaskRepository: TaskStore {
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
        guard try await auth.isAuthorized() else { return }
        try await localStore.upsert(task)
        reminderScheduler.cancelReminders(for: task)
        reminderScheduler.scheduleReminders(for: task)
    }
    
    func update(id: UUID, due: Date?) async throws {
        if var task = try await fetchTask(id: id) {
            task.dueDate = due
            try await localStore.upsert(task)
        }
    }
    
    func insert(title: String, due: Date?) async throws -> UUID {
        guard try await auth.isAuthorized(), let userId = auth.userId else { throw NSError() }
        let id = UUID()
        let task = UserTask(id: id, userId: userId, title: title, dueDate: due)
        try await localStore.upsert(task)
        return id
    }
    
    func delete(_ task: UserTask) async throws {
        guard try await auth.isAuthorized(), let userId = auth.userId else { return }
        try await localStore.delete(id: task.id, userId: userId)
        reminderScheduler.cancelReminders(for: task)
    }
    
    func fetchTask(id: UUID) async throws -> UserTask? {
        guard let taskLocal = try await localStore.fetch(id: id) else {
            return nil
        }
        let task = UserTask(local: taskLocal)
        return task
    }
    
    func fetchAll() async throws -> [UserTask] {
        let tasks = try await localStore.fetchAll()
        return tasks
    }
    
    func fetchTasks(filteredBy filter: TaskFilter?) async throws -> [UserTask] {
        // Prefer local first, or merge with remote if needed
        let tasks = try await localStore.fetchTasks(filteredBy: filter)
        return tasks
    }
    
    func fetchAllUniqueTags() async throws -> [String] {
        let tags = try await localStore.fetchAllUniqueTags()
        return tags
    }
}
//
//extension UserTaskRepository {
//    public func makeTask(title: String, dueDate: Date?) -> UserTask? {
//        guard let userId = auth.userId else { return nil }
//        return UserTask(
//            id: UUID(),
//            userId: userId,
//            title: title,
//            isCompleted: false,
//            createdAt: Date(),
//            updatedAt: Date(),
//            dueDate: dueDate,
//            priority: .medium,
//            tags: [],
//            reminderTriggers: [],
//            version: 1)
//    }
//
//}
