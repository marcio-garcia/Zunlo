//
//  LocalAgendaComputer.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/19/25.
//

import Foundation

final class LocalAgendaComputer: AgendaComputing {
    private let eventRepo: EventStore
    private let taskRepo: TaskStore
    
    init(eventRepo: EventStore, taskRepo: TaskStore) {
        self.eventRepo = eventRepo
        self.taskRepo = taskRepo
    }

    func computeAgenda(range: Range<Date>) async throws -> GetAgendaResult {
        let events = try await eventRepo.fetchOccurrences()
        let occs = try EventOccurrenceService.generate(rawOccurrences: events, in: range, addFakeToday: false)
        
        var tasks: [UserTask]
        let today = Date().startOfDay()
        let tomorrow = today.startOfNextDay()
        let afterTomorrow = tomorrow.startOfNextDay()
        
        let isToday = today == range.lowerBound && tomorrow == range.upperBound
        let isTomorrow = tomorrow == range.lowerBound && afterTomorrow == range.upperBound
        
        if isToday || isTomorrow {
            let filter = TaskFilter(isCompleted: false, untilDueDate: range.upperBound, deleted: false)
            tasks = try await taskRepo.fetchTasks(filteredBy: filter)
        } else {
            let filter = TaskFilter(isCompleted: false, dueDateRange: range, deleted: false)
            tasks = try await taskRepo.fetchTasks(filteredBy: filter)
        }

        // 5) map → Agenda items; sort
        var items: [AgendaItem] = []
        items += occs.map { .event(AgendaEvent(
            id: $0.id, title: $0.title, start: $0.startDate, end: $0.endDate,
            location: $0.location, color: $0.color.rawValue, isOverride: $0.isOverride, isRecurring: $0.isRecurring
        )) }
        items += tasks.map { .task(AgendaTask(
            id: $0.id, title: $0.title, dueDate: $0.dueDate,
            priority: $0.priority.description, tags: $0.tags.map({ $0.text })
        )) }
        items.sort { (a, b) in
            func start(_ x: AgendaItem) -> Date {
                switch x {
                case .event(let e): return e.start
                case .task(let t): return t.dueDate ?? Date.distantFuture
                }
            }
            return start(a) < start(b)
        }

        return GetAgendaResult(start: range.lowerBound, end: range.upperBound, items: items)
    }
}
