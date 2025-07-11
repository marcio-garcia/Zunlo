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

enum ViewState {
    case loading
    case loaded
    case empty
    case error(_ message: String)
}

class CalendarScheduleViewModel: ObservableObject {
    @Published var state = ViewState.loading
    @Published var showAddSheet = false
    @Published var editMode: AddEditEventViewModel.Mode?
    @Published var showEditChoiceDialog = false
    @Published var editChoiceContext: EditChoiceContext?

    // For grouping and access
    var eventOccurrences: [EventOccurrence] = [] // Flat list of all event instances, ready for UI
    
    var repository: EventRepository
    let visibleRange: ClosedRange<Date>
    var locationManager = LocationManager()
    
    var occurObservID: UUID?
    var eventsObservID: UUID?
    var overridesObservID: UUID?
    var rulesObservID: UUID?
        
    struct EditChoiceContext {
        let occurrence: EventOccurrence
        let parentEvent: EventOccurrence
        let rule: RecurrenceRule?
    }
    
    init(repository: EventRepository) {
        self.repository = repository
        let cal = Calendar.current
        let start = cal.date(byAdding: .month, value: -6, to: Date())!
        let end = cal.date(byAdding: .month, value: 6, to: Date())!
        self.visibleRange = start...end

        // Bind to repository data observers
        occurObservID = repository.occurrences.observe(owner: self, fireNow: false, onChange: { [weak self] occurrences in
            self?.handleOccurrences(occurrences)
        })
    }
    
    @MainActor
    func fetchEvents() async {
        do {
            locationManager.startUpdatingLocation()
            try await repository.fetchAll(in: visibleRange)
        } catch {
            state = .error(error.localizedDescription)
            print(error)
        }
    }
    
    // MARK: - Compose occurrences for the UI

    func handleOccurrences(_ occ: [EventOccurrence]) {
        do {
            eventOccurrences = try composeOccurrences(in: visibleRange, occurrences: occ)
            state = occ.isEmpty ? .empty : .loaded
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func composeOccurrences(in range: ClosedRange<Date>? = nil,
                            occurrences: [EventOccurrence]) throws -> [EventOccurrence] {
        let usedRange = range ?? defaultDateRange()
        return try EventOccurrenceService.generate(rawOccurrences: occurrences, in: usedRange)
    }
    
    private func defaultDateRange() -> ClosedRange<Date> {
        let cal = Calendar.current
        let start = cal.date(byAdding: .month, value: -12, to: Date())!
        let end = cal.date(byAdding: .month, value: 12, to: Date())!
        return start...end
    }
    
    var occurrencesByMonthAndDay: [Date: [Date: [EventOccurrence]]] {
        let calendar = Calendar.current
        return Dictionary(
            grouping: eventOccurrences
        ) { occurrence in
            calendar.date(from: calendar.dateComponents([.year, .month],
                                                        from: occurrence.startDate.startOfDay))!
        }
        .mapValues { occurrencesInMonth in
            Dictionary(
                grouping: occurrencesInMonth
            ) { $0.startDate.startOfDay }
            .mapValues { $0.sorted { $0.startDate < $1.startDate } }
        }
    }

    func handleEdit(occurrence: EventOccurrence) {
        if occurrence.isOverride {
            if let override = occurrence.overrides.first(where: { $0.id == occurrence.id }) {
                editMode = .editOverride(override: override)
            }
        } else if let parent = eventOccurrences.first(where: { $0.id == occurrence.eventId }) {
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
    
    private func season(by date: Date) -> Season {
        let month = Calendar.current.component(.month, from: date)
        return season(for: month,
                      hemisphere: hemisphere(for: locationManager.latitude))
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

