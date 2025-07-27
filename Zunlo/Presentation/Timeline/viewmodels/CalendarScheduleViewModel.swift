//
//  CalendarScheduleViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/7/25.
//

import SwiftUI
import MiniSignalEye
import CoreLocation

enum Season: String { case winter, spring, summer, autumn }

class CalendarScheduleViewModel: ObservableObject {
    @Published var state = ViewState.loading
    @Published var showAddSheet = false
    @Published var editMode: AddEditEventViewModel.Mode?
    @Published var showEditChoiceDialog = false
    @Published var editChoiceContext: EditChoiceContext?
    @Published var occurrencesByMonthAndDay: [Date: [Date: [EventOccurrence]]] = [:]
    
    // For grouping and access
    var allOccurrences: [EventOccurrence] = []
    var allRecurringParentOccurrences: [EventOccurrence] = []
    var eventOccurrences: [EventOccurrence] = [] // Flat list of all event instances, ready for UI
    let expansionThreshold: TimeInterval = 60 * 60 * 24 * 30 // ~1 month
    
    var currentTopVisibleDay: Date = Date()
    
    var repository: EventRepository
    var visibleRange: ClosedRange<Date> = Date()...Date()
    var locationService: LocationService
    
    var occurObservID: UUID?
    var eventsObservID: UUID?
    var overridesObservID: UUID?
    var rulesObservID: UUID?
    
    struct EditChoiceContext {
        let occurrence: EventOccurrence
        let parentEvent: EventOccurrence
        let rule: RecurrenceRule?
    }
    
    init(repository: EventRepository,
         locationService: LocationService) {
        
        self.repository = repository
        self.locationService = locationService
        self.visibleRange = defaultDateRange()

        // Bind to repository data observers
        occurObservID = repository.occurrences.observe(owner: self, fireNow: false, onChange: { [weak self] occurrences in
            guard let self else { return }
            self.allOccurrences = occurrences
            self.allRecurringParentOccurrences = occurrences.filter({ $0.isRecurring })
            self.handleOccurrences(occurrences, in: self.visibleRange)
        })
    }
    
    @MainActor
    func fetchEvents() async {
        do {
            locationService.startUpdatingLocation()
            try await repository.fetchAll(in: visibleRange)
        } catch {
            state = .error(error.localizedDescription)
            print(error)
        }
    }
    
    // MARK: - Compose occurrences for the UI

    func handleOccurrences(_ occurrences: [EventOccurrence], in range: ClosedRange<Date>) {
        do {
            eventOccurrences = try EventOccurrenceService.generate(rawOccurrences: occurrences, in: range)
            occurrencesByMonthAndDay = groupOccurrencesByMonthAndDay()
            state = occurrences.isEmpty ? .empty : .loaded(referenceDate: currentTopVisibleDay)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    private func defaultDateRange() -> ClosedRange<Date> {
        let cal = Calendar.current
        let start = cal.date(byAdding: .month, value: -12, to: Date())!
        let end = cal.date(byAdding: .month, value: 12, to: Date())!
        return start...end
    }
    
    func groupOccurrencesByMonthAndDay() -> [Date: [Date: [EventOccurrence]]] {
        let calendar = Calendar.current

        let allDays = Self.allDays(in: visibleRange, calendar: calendar)
        let grouped = Dictionary(grouping: eventOccurrences) { occurrence in
            calendar.date(from: calendar.dateComponents([.year, .month], from: occurrence.startDate.startOfDay))!
        }.mapValues { monthEvents in
            Dictionary(grouping: monthEvents) { $0.startDate.startOfDay }
        }

        // Ensure days with no events are still represented
        var result: [Date: [Date: [EventOccurrence]]] = [:]
        for day in allDays {
            let monthKey = calendar.date(from: calendar.dateComponents([.year, .month], from: day))!
            result[monthKey, default: [:]][day, default: []] = grouped[monthKey]?[day] ?? []
        }
        return result
    }
    
    static func allDays(in range: ClosedRange<Date>, calendar: Calendar) -> [Date] {
        var days: [Date] = []
        var current = calendar.startOfDay(for: range.lowerBound)

        while current <= range.upperBound {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return days
    }

    func handleEdit(occurrence: EventOccurrence) {
        if occurrence.isOverride {
            if let override = occurrence.overrides.first(where: { $0.id == occurrence.id }) {
                editMode = .editOverride(override: override)
            }
        } else if let parent = allRecurringParentOccurrences.first(where: { $0.id == occurrence.eventId }) {
            let rule = occurrence.recurrence_rules.first(where: { $0.eventId == parent.eventId })
            if parent.isRecurring {
                editChoiceContext = EditChoiceContext(occurrence: occurrence, parentEvent: parent, rule: rule)
                showEditChoiceDialog = true
            } else {
                editMode = .editAll(event: parent, recurrenceRule: nil)
            }
        }
    }
    
    func selectEditOnlyThisOccurrence() {
        guard let ctx = editChoiceContext else { return }
        editMode = .editSingle(parentEvent: ctx.parentEvent, recurrenceRule: ctx.rule, occurrence: ctx.occurrence)
        showEditChoiceDialog = false
        editChoiceContext = nil
    }
    func selectEditAllOccurrences() {
        guard let ctx = editChoiceContext else { return }
        editMode = .editAll(event: ctx.parentEvent, recurrenceRule: ctx.rule)
        showEditChoiceDialog = false
        editChoiceContext = nil
    }

    func handleDelete(occurrence: EventOccurrence) {
        // Implement actual delete logic here
    }
    
    func checkIfNearVisibleEdge(_ date: Date) {
        let startDistance = date.timeIntervalSince(visibleRange.lowerBound)
        let endDistance = visibleRange.upperBound.timeIntervalSince(date)

        if startDistance < expansionThreshold {
            expandVisibleRange(toEarlier: true)
        } else if endDistance < expansionThreshold {
            expandVisibleRange(toEarlier: false)
        }
    }
    
    func expandVisibleRange(toEarlier: Bool) {
        let cal = Calendar.current
        if toEarlier {
            let newStart = cal.date(byAdding: .month, value: -6, to: visibleRange.lowerBound)!
            visibleRange = newStart...visibleRange.upperBound
        } else {
            let newEnd = cal.date(byAdding: .month, value: 6, to: visibleRange.upperBound)!
            visibleRange = visibleRange.lowerBound...newEnd
        }
        print("-------- visible range: \(visibleRange)")
        handleOccurrences(allOccurrences, in: visibleRange)
    }

    func handleScrollOffset(_ offset: CGFloat) {
        let screenHeight = UIScreen.main.bounds.height

        if offset > -screenHeight * 0.5 {
            // Near top
            checkIfNearVisibleEdge(visibleRange.lowerBound)
        } else if offset < -screenHeight * 2.5 {
            // Near bottom
            checkIfNearVisibleEdge(visibleRange.upperBound)
        }
    }

    private func season(by date: Date) -> Season {
        let month = Calendar.current.component(.month, from: date)
        return season(for: month,
                      hemisphere: hemisphere(for: locationService.latitude))
    }
    
    private func hemisphere(for latitude: CLLocationDegrees) -> String {
        latitude >= 0 ? "north" : "south"
    }
    
    private func season(for month: Int, hemisphere: String) -> Season {
        // month: 1 = January ... 12 = December
        switch (hemisphere, month) {
        case ("north", 12), ("north", 1), ("north", 2): return .winter
        case ("north", 3), ("north", 4), ("north", 5): return .spring
        case ("north", 6), ("north", 7), ("north", 8): return .summer
        case ("north", 9), ("north", 10), ("north", 11): return .autumn
        case ("south", 6), ("south", 7), ("south", 8): return .winter
        case ("south", 9), ("south", 10), ("south", 11): return .spring
        case ("south", 12), ("south", 1), ("south", 2): return .summer
        case ("south", 3), ("south", 4), ("south", 5): return .autumn
        default: return .summer // fallback
        }
    }
    
    func monthHeaderImageName(for date: Date) -> String {
        return imageName(for: season(by: date))
    }
    
    private func imageName(for season: Season) -> String {
        switch season {
        case .spring: return "spring"
        case .summer: return "summer"
        case .autumn: return "autumn"
        case .winter: return "winter"
        }
    }
}

