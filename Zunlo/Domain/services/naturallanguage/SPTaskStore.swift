//
//  SPTaskStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/1/25.
//

import Foundation
import SmartParseKit

final class SPTaskStore: SmartParseKit.TaskStore {
    typealias T = UserTask
    
    private var taskRepo: UserTaskRepository
    private var auth: AuthProviding
    
    init(taskRepo: UserTaskRepository, auth: AuthProviding) {
        self.taskRepo = taskRepo
        self.auth = auth
    }
    
    func tasks(dueIn range: Range<Date>) async throws -> [T] {
        var endDate = range.upperBound
        endDate = endDate.addingTimeInterval(-0.0001)
        let closedRange = range.lowerBound...endDate
        let filter = TaskFilter(dueDateRange: closedRange)
        return try await taskRepo.fetchTasks(filteredBy: filter)
    }
    
    func allTasks() async throws -> [T] {
        return try await taskRepo.fetchAll()
    }
    
    func createTask(title: String, due: Date?, userInfo: [String : Any]?) async throws -> T {
        guard let userId = auth.userId else {
            throw LocalDBError.unauthorized
        }
        let task = UserTask(
            id: UUID(),
            userId: userId,
            title: title,
            notes: nil,
            isCompleted: false,
            createdAt: Date(),
            updatedAt: Date(),
            dueDate: due,
            priority: .medium,
            parentEventId: nil,
            tags: [],
            reminderTriggers: nil,
            deletedAt: nil,
            needsSync: true,
            version: nil)
        try await taskRepo.upsert(task)
        return task
    }


    
    func updateTask(id: UUID, title: String?) async throws {
        
    }
    
    func rescheduleTask(id: UUID, due: Date) async throws {
        
    }
}
