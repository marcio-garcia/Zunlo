//
//  RealmUserTaskLocalStoreTests.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/26/25.
//

import XCTest
import RealmSwift
@testable import Zunlo

final class RealmUserTaskLocalStoreTests: XCTestCase {

    private var db: DatabaseActor!
    private var store: RealmUserTaskLocalStore!
//    private var testConfig: Realm.Configuration!
    
    override func setUp() async throws {
        try await super.setUp()
        
        let inMemoryID = "UserTaskTestRealm-\(UUID().uuidString)"
        db = TestDBFactory.makeActor(label: inMemoryID)
        // Inject the actor into your store(s)
        store = RealmUserTaskLocalStore(db: db)
    }

    override func tearDown() {
        // Let the actor deallocate; anchorRealm will be released -> in-memory wiped
        db = nil
        store = nil
        super.tearDown()
    }
    
    // MARK: - Helpers

    private func createTask(title: String, tags: [String]) async throws {
        let userId = UUID()
        let task = UserTaskRemote(
            id: UUID(),
            userId: userId,
            title: title,
            isCompleted: false,
            createdAt: Date(),
            updatedAt: Date(),
            priority: .low,
            tags: tags
        )
        
        try await store.upsert(task)
        let all = try await store.fetchAll(userId: userId)
        print("🧪 Realm contains:", all.count)
    }

    // MARK: - Tests
    
    func test_fetchTasks_withoutFilter_returnsAllTasks() async throws {
        try await createTask(title: "Task 1", tags: ["work"])
        try await createTask(title: "Task 2", tags: ["personal"])
        let userId = UUID()
        
        let tasks = try await store.fetchTasks(filteredBy: nil, userId: userId)
        
        XCTAssertEqual(tasks.count, 2)
        let titles = Set(tasks.map { $0.title })
        XCTAssertTrue(titles.contains("Task 1"))
        XCTAssertTrue(titles.contains("Task 2"))
    }

    func test_fetchTasks_withTagFilter_returnsMatchingTasks() async throws {
        try await createTask(title: "Task 1", tags: ["work"])
        try await createTask(title: "Task 2", tags: ["personal"])
        try await createTask(title: "Task 3", tags: ["work", "focus"])
        let userId = UUID()
        
        let tasks = try await store.fetchTasks(filteredBy: TaskFilter(tags: ["work"]), userId: userId)

        XCTAssertEqual(tasks.count, 2)
        let titles = Set(tasks.map { $0.title })
        XCTAssertTrue(titles.contains("Task 1"))
        XCTAssertTrue(titles.contains("Task 3"))
    }

    func test_fetchTasks_withNonMatchingTag_returnsEmpty() async throws {
        try await createTask(title: "Task 1", tags: ["work"])
        let userId = UUID()
        
        let tasks = try await store.fetchTasks(filteredBy: TaskFilter(tags: ["nonexistent"]), userId: userId)

        XCTAssertTrue(tasks.isEmpty)
    }

    func test_fetchAllUniqueTags_returnsDeduplicatedSortedTags() async throws {
        try await createTask(title: "Task 1", tags: ["work", "focus"])
        try await createTask(title: "Task 2", tags: ["focus", "personal"])
        try await createTask(title: "Task 3", tags: ["  work  "]) // With whitespace
        let userId = UUID()
        
        let tags = try await store.fetchAllUniqueTags(userId: userId)

        XCTAssertEqual(tags, ["focus", "personal", "work"])
    }

    func test_fetchAllUniqueTags_returnsEmptyIfNoTasks() async throws {
        let userId = UUID()
        let tags = try await store.fetchAllUniqueTags(userId: userId)
        XCTAssertTrue(tags.isEmpty)
    }
}
