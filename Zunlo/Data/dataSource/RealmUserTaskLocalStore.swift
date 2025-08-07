//
//  RealmUserTaskLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import Foundation
import RealmSwift

final class RealmUserTaskLocalStore: UserTaskLocalStore {

    private let configuration: Realm.Configuration
    
    init(configuration: Realm.Configuration = .defaultConfiguration) {
        self.configuration = configuration
    }
    
    func save(_ remote: UserTaskRemote) async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let local = UserTaskLocal(from: remote)
            try realm.write {
                realm.add(local, update: .all)
            }
        }.value
    }

    func update(_ remote: UserTaskRemote) async throws {
        // The safest: update by ID, copy fields over
        let id = remote.id
        try await Task.detached(priority: .background) {
            let realm = try Realm(configuration: self.configuration)
            guard let existing = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: id) else { return }
            try realm.write {
                existing.getUpdateFields(remote: remote)
            }
        }.value
    }

    func delete(id: UUID) async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm(configuration: self.configuration)
            guard let existing = realm.object(ofType: UserTaskLocal.self, forPrimaryKey: id) else { return }
            try realm.write {
                realm.delete(existing)
            }
        }.value
    }

    func deleteAll(for userId: UUID) async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm(configuration: self.configuration)
            let events = realm.objects(UserTaskLocal.self).filter("userId == %@", userId)
            try realm.write {
                realm.delete(events)
            }
        }.value
    }
    
    func deleteAll() async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm(configuration: self.configuration)
            try realm.write {
                realm.delete(realm.objects(UserTaskLocal.self))
            }
        }.value
    }
    
    func fetchAll() async throws -> [UserTask] {
        try await Task.detached(priority: .background) {
            let realm = try Realm(configuration: self.configuration)
            let eventsLocal = Array(
                realm.objects(UserTaskLocal.self).sorted(by: [
                    SortDescriptor(keyPath: "priority", ascending: false),
                    SortDescriptor(keyPath: "dueDate", ascending: true)
                ])
            )
            
            return eventsLocal.map { $0.toDomain() }
        }.value
    }
    
    func fetchTasks(filteredBy filter: TaskFilter? = nil) async throws -> [UserTask] {
        try await Task.detached(priority: .background) {
            let realm = try Realm(configuration: self.configuration)
            var predicates: [NSPredicate] = []

            if let tags = filter?.tags, !tags.isEmpty {
                predicates.append(NSPredicate(format: "ANY tags IN %@", tags))
            }

            if let userId = filter?.userId {
                predicates.append(NSPredicate(format: "userId == %@", userId as CVarArg))
            }

            if let priority = filter?.priority {
                predicates.append(NSPredicate(format: "priority == %@", priority.rawValue))
            }

            if let isCompleted = filter?.isCompleted {
                predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: isCompleted)))
            }

            if let range = filter?.dueDateRange {
                predicates.append(NSPredicate(format: "dueDate >= %@ AND dueDate <= %@", range.lowerBound as NSDate, range.upperBound as NSDate))
            }

            var query = realm.objects(UserTaskLocal.self)
            if !predicates.isEmpty {
                let compound = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                query = query.filter(compound)
            }

            let sorted = query.sorted(by: [
                SortDescriptor(keyPath: "priority", ascending: false),
                SortDescriptor(keyPath: "dueDate", ascending: true)
            ])

            return sorted.map { $0.toDomain() }
        }.value
    }

    
    func fetchAllUniqueTags() async throws -> [String] {
        try await Task.detached(priority: .background) {
            let realm = try Realm(configuration: self.configuration)
            let tasks = realm.objects(UserTaskLocal.self)
            let allTags = tasks.flatMap { $0.tags }
            let uniqueTags = Set(allTags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            return Array(uniqueTags).sorted()
        }.value
    }
}
