//
//  TodayViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/18/25.
//

import SwiftUI
import SupabaseSDK
import MiniSignalEye
import CoreLocation

@MainActor
final class TodayViewModel: ObservableObject, @unchecked Sendable {
    @Published var todaysTasks: [UserTask] = []
    @Published var todaysEvents: [EventOccurrence] = []
    @Published var greeting: String = ""
    @Published var weather: WeatherInfo?
    @Published var eventEditHandler = EventEditHandler()
    
    private let taskRepository: UserTaskRepository
    private let eventRepository: EventRepository
    private let locationService: LocationService
    
    let errorHandler = ErrorHandler()

    init(
        taskRepository: UserTaskRepository,
        eventRepository: EventRepository,
        locationService: LocationService
    ) {
        self.taskRepository = taskRepository
        self.eventRepository = eventRepository
        self.locationService = locationService
        
        locationService.startUpdatingLocation()
        
        observeRepositories()
        updateGreeting()
    }

    private func observeRepositories() {
        taskRepository.tasks.observe(owner: self, fireNow: false) { [weak self] tasks in
            let today = Calendar.current.startOfDay(for: Date())
            let filtered = tasks.filter {
                if let due = $0.dueDate {
                    return Calendar.current.isDate(due, inSameDayAs: today)
                } else {
                    return !$0.isCompleted
                }
            }
            DispatchQueue.main.async {
                self?.todaysTasks = filtered
            }
        }

        eventRepository.occurrences.observe(owner: self, fireNow: false) { [weak self] occurrences in
            let today = Calendar.current.startOfDay(for: Date())
            let filtered = occurrences.filter {
                Calendar.current.isDate($0.startDate, inSameDayAs: today)
            }
            
            DispatchQueue.main.async {
                self?.eventEditHandler.allRecurringParentOccurrences = occurrences.filter({ $0.isRecurring })
                self?.todaysEvents = filtered
            }
        }
    }

    func fetchData() async {
        do {
            try await taskRepository.fetchAll()
            try await eventRepository.fetchAll()
        } catch {
            errorHandler.handle(error)
        }
    }
    
    func onEventEditTap(_ occurrence: EventOccurrence) {
        eventEditHandler.handleEdit(occurrence: occurrence)
    }

    func toggleTaskCompletion(for task: UserTask) {
        var updated = task
        updated.isCompleted.toggle()
        Task {
            try? await taskRepository.update(updated)
            await fetchData()
        }
    }
    
    private func updateGreeting(date: Date = Date()) {
        let hour = Calendar.current.component(.hour, from: date)
        greeting = switch hour {
        case 5..<12: "Good morning!"
        case 12..<17: "Good afternoon!"
        case 17..<22: "Good evening!"
        default: "Good night!"
        }
    }
    
    func fetchWeather() async {
        guard let coordinate = locationService.coordinate else { return }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            if let info = try await WeatherService.shared.fetchWeather(for: Date(), location: location) {
                self.weather = info
            }
        } catch {
            print("Failed to fetch weather:", error)
        }
    }
}
