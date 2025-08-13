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
import AdStack

final class TodayViewModel: ObservableObject, @unchecked Sendable {
    @Published var state: ViewState = .loading
    @Published var weather: WeatherInfo?
    @Published var eventEditHandler = EventEditHandler()

    private let taskRepo: UserTaskRepository
    private let eventRepo: EventRepository
    private let locationService: LocationService
    private let adManager: AdMobManager
    
    @MainActor let errorHandler = ErrorHandler()

    var todayTasks: [UserTask] = []
    var todayEvents: [EventOccurrence] = []
    var greeting: String = ""

    init(
        taskRepo: UserTaskRepository,
        eventRepo: EventRepository,
        locationService: LocationService,
        adManager: AdMobManager
    ) {
        self.taskRepo = taskRepo
        self.eventRepo = eventRepo
        self.locationService = locationService
        self.adManager = adManager
        
        locationService.startUpdatingLocation()
        
        observeRepositories()
        updateGreeting()
    }

    private func observeRepositories() {
        taskRepo.lastTaskAction.observe(owner: self, queue: DispatchQueue.main, fireNow: false) { [weak self] action in
            if case .fetch(let tasks) = action {
                
                let today = Date().startOfDay
                
                let filtered = tasks.filter {
                    if let due = $0.dueDate {
                        return due <= today && !$0.isCompleted
                    } else {
                        return !$0.isCompleted
                    }
                }
                
                DispatchQueue.main.async {
                    self?.todayTasks = filtered
                    self?.state = filtered.isEmpty ? .empty : .loaded
                }

            }
        }
        
        eventRepo.lastEventAction.observe(owner: self, queue: DispatchQueue.main, fireNow: false) { [weak self] action in
            if case .fetch(let occ) = action {
                let today = Date().startOfDay
                guard let tomorrow = Calendar.appDefault.date(byAdding: .day, value: 1, to: today) else { return }
                self?.handleOccurrences(occ, in: today...tomorrow)
            }
        }
    }
    
    func fetchData() async {
        do {
            let taskFetcher = UserTaskFetcher(repo: taskRepo)
            let _ = try await taskFetcher.fetchTasks()
            
            let eventFetcher = EventFetcher(repo: eventRepo)
            let _ = try await eventFetcher.fetchOccurrences()
            
        } catch {
            await errorHandler.handle(error)
        }
    }
    
    func handleOccurrences(_ occurrences: [EventOccurrence], in range: ClosedRange<Date>) {
        do {
            let today = Calendar.appDefault.startOfDay(for: Date())
            
            let eventsWithRecurringOcc = try EventOccurrenceService.generate(rawOccurrences: occurrences, in: range)
            
            let filtered = eventsWithRecurringOcc.filter {
                Calendar.appDefault.isDate($0.startDate, inSameDayAs: today)
            }
            
            todayEvents = filtered

            DispatchQueue.main.async {
                self.eventEditHandler.allRecurringParentOccurrences = occurrences.filter({ $0.isRecurring })
                self.state = occurrences.isEmpty ? .empty : .loaded
            }
        } catch {
            DispatchQueue.main.async {
                self.state = .error(error.localizedDescription)
            }
        }
    }
    
    func onEventEditTap(_ occurrence: EventOccurrence) {
        eventEditHandler.handleEdit(occurrence: occurrence)
    }

    func toggleTaskCompletion(for task: UserTask) {
        var updated = task
        updated.isCompleted.toggle()
        Task {
            let taskEditor = TaskEditor(repo: taskRepo)
            try? await taskEditor.update(makeInput(task: updated), id: task.id)
            await fetchData()
        }
    }
    
    private func updateGreeting(date: Date = Date()) {
        let hour = Calendar.appDefault.component(.hour, from: date)
        greeting = switch hour {
        case 5..<12: String(localized: "Good morning!")
        case 12..<17: String(localized: "Good afternoon!")
        case 17..<22: String(localized: "Good evening!")
        default: String(localized: "Good night!")
        }
    }
    
    func fetchWeather() async {
        do {
            WeatherService.shared.location = locationService.location()
            if let info = try await WeatherService.shared.fetchWeather(for: Date()) {
                DispatchQueue.main.async {
                    self.weather = info
                    self.locationService.stop()
                }
            }
        } catch {
            print("Failed to fetch weather:", error)
        }
    }
    
    private func makeInput(task: UserTask) -> AddTaskInput {
        AddTaskInput(
            title: task.title,
            notes: task.notes,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted,
            priority: task.priority,
            tags: task.tags,
            reminderTriggers: task.reminderTriggers
        )
    }
}

extension TodayViewModel {
    func loadAds() async {
        await adManager.loadInterstitial(for: .openCalendar)
        await adManager.loadRewarded(for: .chat)
    }
    
    @MainActor
    func showAd(
        type: AdType,
        onDismiss: (() -> Void)? = nil,
        onRewardEarned: ((Double, String) -> Void)? = nil
    ) {
        if let rootVC = UIApplication.shared.rootViewController {
            adManager.showAd(
                type, // .interstitial(.openCalendar),
                from: rootVC) { event in
                    switch event {
                    case .didDismiss:
                        onDismiss?()
                    case .didFailToPresent(let error):
                        print("❌ Failed to present: \(error.localizedDescription)")
                    case .didRecordImpression:
                        print("📺 Interstitial ad presented")
                    case .didClick:
                        print("🖱️ Interstitial ad clicked")
                    }
                } onRewardEarned: { amount, type in
                    onRewardEarned?(amount, type)
                }
        }
    }
}
