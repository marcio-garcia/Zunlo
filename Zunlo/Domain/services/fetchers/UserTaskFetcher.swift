//
//  UserTaskFetcher.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/10/25.
//

import Foundation

protocol UserTaskFetcherService {
    func fetchTasks(filteredBy filter: TaskFilter?) async throws -> [UserTask]
    func fetchAllUniqueTags() async throws -> [String]
}

extension UserTaskFetcherService {
    func fetchTasks() async throws -> [UserTask] {
        try await fetchTasks(filteredBy: nil)
    }
}

final class UserTaskFetcher: UserTaskFetcherService {
    private let repo: UserTaskRepository
    private let clock: () -> Date
    
    init(repo: UserTaskRepository, clock: @escaping () -> Date = Date.init) {
        self.repo = repo
        self.clock = clock
    }
    
    func fetchTasks(filteredBy filter: TaskFilter?) async throws -> [UserTask] {
        guard let filter else {
            return try await repo.fetchAll()
        }
        return try await repo.fetchTasks(filteredBy: filter)
    }
    
    func fetchAllUniqueTags() async throws -> [String] {
        try await repo.fetchAllUniqueTags()
    }
}
