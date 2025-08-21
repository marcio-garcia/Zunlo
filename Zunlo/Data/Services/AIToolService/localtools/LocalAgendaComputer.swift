//
//  LocalAgendaComputer.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/19/25.
//

import Foundation

final class LocalAgendaComputer: AgendaComputing {
    private let toolRepo: DomainRepositories
    private let cal: Calendar
    
    init(toolRepo: DomainRepositories, calendar: Calendar = .appDefault) {
        self.toolRepo = toolRepo
        self.cal = calendar
    }

    func computeAgenda(range: Range<Date>, timezone: TimeZone) async throws -> GetAgendaResult {
        let events = try await toolRepo.fetchOccurrences()
        let occs = try EventOccurrenceService.generate(rawOccurrences: events, in: range, addFakeToday: false)
        let tasks = try await toolRepo.fetchTasks(range: range)

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

        return GetAgendaResult(start: range.lowerBound, end: range.upperBound, timezone: timezone.identifier, items: items)
    }
}
