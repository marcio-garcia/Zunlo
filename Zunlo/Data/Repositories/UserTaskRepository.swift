//
//  UserTaskRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation

protocol TaskStore {
    func fetchAll() async throws -> [UserTask]
    func fetchTasks(filteredBy filter: TaskFilter?) async throws -> [UserTask]
    func upsert(_ task: UserTask) async throws
    func insert(title: String, due: Date?) async throws -> UUID
    func update(
        id: UUID,
        title: String?,
        dueDate: Date?,
        tags: [String]?,
        reminderTriggers: [ReminderTrigger]?,
        priority: UserTaskPriority?,
        notes: String?
    ) async throws
    func delete(taskId: UUID) async throws
}

extension TaskStore {
    func update(
        id: UUID,
        title: String? = nil,
        dueDate: Date? = nil,
        tags: [String]? = nil,
        reminderTriggers: [ReminderTrigger]? = nil,
        priority: UserTaskPriority? = nil,
        notes: String? = nil
    ) async throws {
        try await update(id: id, title: title, dueDate: dueDate, tags: tags, reminderTriggers: reminderTriggers, priority: priority, notes: notes)
    }
}

final class UserTaskRepository: TaskStore {
    private let auth: AuthProviding
    private let localStore: UserTaskLocalStore
    private let reminderScheduler: ReminderScheduler
    private let calendar = Calendar.appDefault
    
    init(
        auth: AuthProviding,
        localStore: UserTaskLocalStore
    ) {
        self.auth = auth
        self.localStore = localStore
        self.reminderScheduler = ReminderScheduler()
    }
    
    func upsert(_ task: UserTask) async throws {
        guard try await auth.isAuthorized() else { return }
        try await localStore.upsert(task)
        await reminderScheduler.cancelReminders(for: task)
        try? await reminderScheduler.scheduleReminders(for: task)
    }
    
    func update(
        id: UUID,
        title: String?,
        dueDate: Date?,
        tags: [String]?,
        reminderTriggers: [ReminderTrigger]?,
        priority: UserTaskPriority?,
        notes: String?
    ) async throws {
        if var task = try await fetchTask(id: id) {
            if let due = dueDate { task.dueDate = due }
            if let t = title { task.title = t }
            if let tg = tags { task.tags = tg.map({ Tag(id: UUID(), text: $0, color: "", selected: false) })}
            if let r = reminderTriggers { task.reminderTriggers = r }
            if let p = priority { task.priority = p }
            if let n = notes { task.notes = n }
            try await localStore.upsert(task)
        }
    }
    
    func insert(title: String, due: Date?) async throws -> UUID {
        guard try await auth.isAuthorized(), let userId = await auth.userId else { throw NSError() }
        let id = UUID()
        let task = UserTask(id: id, userId: userId, title: title, dueDate: due)
        try await localStore.upsert(task)
        return id
    }
    
    func delete(_ task: UserTask) async throws {
        guard try await auth.isAuthorized(), let userId = await auth.userId else { return }
        try await localStore.delete(id: task.id, userId: userId)
        await reminderScheduler.cancelReminders(for: task)
    }

    func delete(taskId: UUID) async throws {
        guard try await auth.isAuthorized(), let userId = await auth.userId else { return }
        if let task = try await localStore.fetch(id: taskId) {
            if let reminderTriggers = UserTask(local: task).reminderTriggers, !reminderTriggers.isEmpty {
                await reminderScheduler.cancelReminders(itemId: taskId, reminderTriggers: reminderTriggers, itemTitle: task.title)
            }
            try await localStore.delete(id: taskId, userId: userId)
        }
    }
    
    func fetchTask(id: UUID) async throws -> UserTask? {
        guard try await auth.isAuthorized() else { return nil }
        guard let taskLocal = try await localStore.fetch(id: id) else {
            return nil
        }
        let task = UserTask(local: taskLocal)
        return task
    }
    
    func fetchAll() async throws -> [UserTask] {
        guard try await auth.isAuthorized(), let userId = await auth.userId else { return [] }
        let tasks = try await localStore.fetchAll(userId: userId)
        return tasks
    }
    
    func fetchTasks(filteredBy filter: TaskFilter?) async throws -> [UserTask] {
        guard try await auth.isAuthorized(), let userId = await auth.userId else { return [] }
        let tasks = try await localStore.fetchTasks(filteredBy: filter, userId: userId)
        return tasks
    }
    
    func fetchAllUniqueTags() async throws -> [String] {
        guard try await auth.isAuthorized(), let userId = await auth.userId else { return [] }
        let tags = try await localStore.fetchAllUniqueTags(userId: userId)
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
