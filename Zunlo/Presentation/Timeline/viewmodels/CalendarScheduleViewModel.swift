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

struct EditChoiceContext {
    let occurrence: EventOccurrence
    let parentEvent: EventOccurrence
    let rule: RecurrenceRule?
}

class CalendarScheduleViewModel: ObservableObject {
    @Published var state = ViewState.loading
    @Published var showAddSheet = false
    @Published var editChoiceContext: EditChoiceContext?
    @Published var eventEditHandler = EventEditHandler()
    
    var eventOccurrences: [EventOccurrence] = []
    var allOccurrences: [EventOccurrence] = []
    
    private let weatherCache = WeatherCache()

    let edgeExecutor = DebouncedExecutor(delay: 0.2)
    private var isCheckingEdge = false
    var itemDateToScrollTo = Date()
    
    let userId: UUID
    var eventRepo: EventRepository
    var visibleRange: Range<Date> = Date()..<Date()
    var locationService: LocationService
    
    init(
        userId: UUID,
        eventRepo: EventRepository,
        locationService: LocationService
    ) {
        self.userId = userId
        self.eventRepo = eventRepo
        self.locationService = locationService
        self.visibleRange = defaultDateRange()
    }
    
    @MainActor
    func fetchEvents() async -> [EventOccurrence] {
        do {
            locationService.startUpdatingLocation()
            // TODO: change to fetch occurrences filtered by date range
            let occurrences = try await eventRepo.fetchOccurrences()
            allOccurrences = occurrences
            eventEditHandler.allRecurringParentOccurrences = occurrences.filter({ $0.isRecurring })
            eventOccurrences = try handleOccurrences(occurrences, in: self.visibleRange)
            return eventOccurrences
        } catch {
            state = .error(error.localizedDescription)
            return []
        }
    }
    
    func handleOccurrences(_ occurrences: [EventOccurrence], in range: Range<Date>) throws -> [EventOccurrence] {
        let occ = try EventOccurrenceService.generate(rawOccurrences: occurrences, in: range)
        if occ.count == 1, let first = occ.first, first.isFakeOccForEmptyToday {
            return []
        } else {
            return occ
        }
    }
    
    private func defaultDateRange() -> Range<Date> {
        let cal = Calendar.appDefault
        let now = Date()
        let start = cal.date(byAdding: .month, value: -12, to: now)!
        let end = cal.date(byAdding: .month, value: 12, to: now)!
        return start..<end
    }
    
    func groupOccurrencesByMonthAndDay() -> [Date: [Date: [EventOccurrence]]] {
        let calendar = Calendar.appDefault

//        let allDays = Self.allDays(in: visibleRange, calendar: calendar)
        let grouped = Dictionary(grouping: eventOccurrences) { occurrence in
            calendar.date(from: calendar.dateComponents([.year, .month], from: occurrence.startDate.startOfDay()))!
        }.mapValues { monthEvents in
            Dictionary(grouping: monthEvents) { $0.startDate.startOfDay() }
        }

        return grouped
        
        // Ensure days with no events are still represented
//        var result: [Date: [Date: [EventOccurrence]]] = [:]
//        for day in allDays {
//            let monthKey = calendar.date(from: calendar.dateComponents([.year, .month], from: day))!
//            result[monthKey, default: [:]][day, default: []] = grouped[monthKey]?[day] ?? []
//        }
//        return result
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

    func onEventEditTapped(_ occurrence: EventOccurrence, completion: (AddEditEventViewMode?, Bool) -> Void) {
        eventEditHandler.handleEdit(occurrence: occurrence) { mode, showDialog in
            completion(mode, showDialog)
        }
    }
}

// MARK: Expand range

extension CalendarScheduleViewModel {
    func checkTop(date: Date) {
        if !isCheckingEdge {
            isCheckingEdge = true
//            edgeExecutor.execute(id: "top-edge-check") {
//                self.itemDateToScrollTo = date
//                self.expandVisibleRange(toEarlier: true)
//                self.isCheckingEdge = false
//            }
        }
    }
    
    func checkBottom(date: Date) {
        if !isCheckingEdge {
            isCheckingEdge = true
//            edgeExecutor.execute(id: "bottom-edge-check") {
//                self.itemDateToScrollTo = date
//                self.expandVisibleRange(toEarlier: false)
//                self.isCheckingEdge = false
//            }
        }
    }
    
    func expandVisibleRange(toEarlier: Bool) throws -> [EventOccurrence] {
        let cal = Calendar.appDefault
        if toEarlier {
            let newStart = cal.date(byAdding: .month, value: -6, to: visibleRange.lowerBound)!
            itemDateToScrollTo = visibleRange.lowerBound
            visibleRange = newStart..<visibleRange.upperBound
        } else {
            let newEnd = cal.date(byAdding: .month, value: 6, to: visibleRange.upperBound)!
            visibleRange = visibleRange.lowerBound..<newEnd
        }
        return try handleOccurrences(allOccurrences, in: visibleRange)
    }
}

// MARK: Weather info

extension CalendarScheduleViewModel {
    @MainActor
    func fetchWeather(for date: Date, completion: @escaping (WeatherInfo?) -> Void) {
        let normalizedDate = Calendar.appDefault.startOfDay(for: date)

        if let cached = weatherCache.get(for: normalizedDate) {
            completion(cached)
            return
        }

        guard Calendar.appDefault.isDateInToday(date) else {
            completion(nil)
            return
        }

        Task { [weak self] in
            guard let self = self else { return }

            do {
                if let info = try await WeatherProvider.shared.fetchWeather(for: date) {
                    weatherCache.set(info, for: normalizedDate)
                    DispatchQueue.main.async {
                        completion(info)
                    }
                } else {
                    completion(nil)
                }
            } catch {
                print("Weather error: \(error)")
                completion(nil)
            }
        }
    }

}

// MARK: Event month header image selection

extension CalendarScheduleViewModel {
    private func season(by date: Date) -> Season {
        let month = Calendar.appDefault.component(.month, from: date)
        return season(for: month,
                      hemisphere: hemisphere(for: locationService.coordinate?.latitude ?? 40))
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
