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
    private let calendar = Calendar.appDefault

    var lastTaskAction = Observable<LastTaskAction>(.none)
    
    init(localStore: UserTaskLocalStore, remoteStore: UserTaskRemoteStore) {
        self.localStore = localStore
        self.remoteStore = remoteStore
        self.reminderScheduler = ReminderScheduler()
    }

    func upsert(_ task: UserTask) async throws {
        try await localStore.upsert(task)
        reminderScheduler.cancelReminders(for: task)
        reminderScheduler.scheduleReminders(for: task)
        lastTaskAction.value = .update
    }

    func delete(_ task: UserTask) async throws {
        try await localStore.delete(id: task.id)
        reminderScheduler.cancelReminders(for: task)
        lastTaskAction.value = .delete
    }
    
    @discardableResult
    func fetchAll() async throws -> [UserTask] {
        let tasks = try await localStore.fetchAll()
        lastTaskAction.value = .fetch(tasks)
        return tasks
    }
    
    @discardableResult
    func fetchTasks(filteredBy filter: TaskFilter?) async throws -> [UserTask] {
        // Prefer local first, or merge with remote if needed
        let tasks = try await localStore.fetchTasks(filteredBy: filter)
        lastTaskAction.value = .fetch(tasks)
        return tasks
    }
    
    @discardableResult
    func fetchAllUniqueTags() async throws -> [String] {
        let tags = try await localStore.fetchAllUniqueTags()
        lastTaskAction.value = .fetchTags(tags)
        return tags
    }
}

extension UserTaskRepository: TaskSuggestionEngine {

    /// Count of open tasks where dueDate is strictly before "now".
    public func overdueCount(on date: Date) async -> Int {
        do {
            let all = try await localStore.fetchTasks(filteredBy: TaskFilter(
                // isCompleted filter supported; dueDateRange inclusive
                isCompleted: false,
                dueDateRange: Date.distantPast...date
            ))
            return all.count
        } catch {
            return 0
        }
    }

    /// Count of open tasks due within the calendar day of `date`.
    public func dueTodayCount(on date: Date) async -> Int {
        let range = calendar.dayRange(containing: date)
        let closedRange = range.lowerBound...range.upperBound
        do {
            let all = try await localStore.fetchTasks(filteredBy: TaskFilter(
                isCompleted: false,
                dueDateRange: closedRange
            ))
            return all.count
        } catch {
            return 0
        }
    }

    /// Count of open tasks marked high priority (>= 2). Adjust if you use enums.
    public func highPriorityCount(on date: Date) async -> Int {
        // TaskFilter only supports equality for priority; we’ll filter in-memory for >= 2
        do {
            let all = try await localStore.fetchTasks(filteredBy: TaskFilter(isCompleted: false))
            return all.filter { $0.priority == .high }.count
        } catch {
            return 0
        }
    }

    /// Top unscheduled tasks: open, no scheduledStart, sorted by (priority desc, dueDate asc, title).
    public func topUnscheduled(limit: Int) async -> [UserTask] {
        do {
            let all = try await localStore.fetchAll()
            return all
                .filter { !$0.isCompleted && $0.dueDate == nil }
                .sorted {
                    if $0.priority != $1.priority { return $0.priority.rawValue > $1.priority.rawValue }
                    switch ($0.dueDate, $1.dueDate) {
                    case let (l?, r?): return l < r
                    case (_?, nil):    return true
                    case (nil, _?):    return false
                    default:           return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    }
                }
                .prefix(limit)
                .map { $0 }
        } catch {
            return []
        }
    }

    /// Derive a "typical start time" heuristic from the user's past N days.
    /// v1: fallback to 9:00 if unknown. You can refine by analyzing the first scheduled item per day.
    public func typicalStartTimeComponents() async -> DateComponents? {
        // Simple heuristic: look back 14 days for earliest of (task.scheduledStart, event.start)
        // Here we only have tasks; events considered in EventRepo. Fallback 9:00 if unknown.
        do {
            let all = try await localStore.fetchAll()
            let cal = calendar
            let cutoff = cal.date(byAdding: .day, value: -14, to: Date()) ?? Date()
            let starts = all
                .compactMap { $0.dueDate }
                .filter { $0 >= cutoff }
                .map { cal.dateComponents([.hour, .minute], from: $0) }

            if let mode = starts.min(by: { ($0.hour ?? 24, $0.minute ?? 60) < ($1.hour ?? 24, $1.minute ?? 60) }) {
                return DateComponents(hour: mode.hour, minute: mode.minute)
            }
        } catch { /* ignore */ }
        return DateComponents(hour: 9, minute: 0)
    }
}
