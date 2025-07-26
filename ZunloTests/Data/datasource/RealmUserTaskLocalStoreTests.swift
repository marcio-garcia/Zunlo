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

    private var realm: Realm!
    private var store: RealmUserTaskLocalStore!
    private var testConfig: Realm.Configuration!
    
    override func setUp() async throws {
        let inMemoryID = "UserTaskTestRealm-\(UUID().uuidString)"
        testConfig = Realm.Configuration(
            inMemoryIdentifier: inMemoryID,
            schemaVersion: 1 // explicitly set a schema version
        )
        
        try await MainActor.run {
            realm = try Realm(configuration: testConfig)
            try realm.write {
                realm.deleteAll()
            }
        }
        
        store = RealmUserTaskLocalStore(configuration: testConfig)
    }

    // MARK: - Helpers

    private func createTask(title: String, tags: [String]) async throws {
        try await MainActor.run {
            print("createTask - Using in-memory ID:", testConfig.inMemoryIdentifier ?? "nil")
            let task = UserTaskLocal()
            task.id = UUID()
            task.userId = UUID()
            task.title = title
            task.tags.append(objectsIn: tags)
            try realm.write {
                realm.add(task)
            }
            let count = realm.objects(UserTaskLocal.self).count
            print("🧪 Realm contains:", count)
        }
    }

    // MARK: - Tests
    
    func test_fetchTasks_withoutFilter_returnsAllTasks() async throws {
        try await createTask(title: "Task 1", tags: ["work"])
        try await createTask(title: "Task 2", tags: ["personal"])
        
        let tasks = try await store.fetchTasks(filteredBy: nil)
        
        XCTAssertEqual(tasks.count, 2)
        let titles = Set(tasks.map { $0.title })
        XCTAssertTrue(titles.contains("Task 1"))
        XCTAssertTrue(titles.contains("Task 2"))
    }

    func test_fetchTasks_withTagFilter_returnsMatchingTasks() async throws {
        try await createTask(title: "Task 1", tags: ["work"])
        try await createTask(title: "Task 2", tags: ["personal"])
        try await createTask(title: "Task 3", tags: ["work", "focus"])

        let tasks = try await store.fetchTasks(filteredBy: TaskFilter(tags: ["work"]))

        XCTAssertEqual(tasks.count, 2)
        let titles = Set(tasks.map { $0.title })
        XCTAssertTrue(titles.contains("Task 1"))
        XCTAssertTrue(titles.contains("Task 3"))
    }

    func test_fetchTasks_withNonMatchingTag_returnsEmpty() async throws {
        try await createTask(title: "Task 1", tags: ["work"])

        let tasks = try await store.fetchTasks(filteredBy: TaskFilter(tags: ["nonexistent"]))

        XCTAssertTrue(tasks.isEmpty)
    }

    func test_fetchAllUniqueTags_returnsDeduplicatedSortedTags() async throws {
        try await createTask(title: "Task 1", tags: ["work", "focus"])
        try await createTask(title: "Task 2", tags: ["focus", "personal"])
        try await createTask(title: "Task 3", tags: ["  work  "]) // With whitespace

        let tags = try await store.fetchAllUniqueTags()

        XCTAssertEqual(tags, ["focus", "personal", "work"])
    }

    func test_fetchAllUniqueTags_returnsEmptyIfNoTasks() async throws {
        let tags = try await store.fetchAllUniqueTags()
        XCTAssertTrue(tags.isEmpty)
    }
}
