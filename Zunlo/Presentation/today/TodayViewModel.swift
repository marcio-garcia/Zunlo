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

    private let taskFetcher: UserTaskFetcherService
    private let taskEditor: TaskEditorService
    private let eventFetcher: EventFetcherService
    private let locationService: LocationService
    private let adManager: AdMobManager
    
    @MainActor let errorHandler = ErrorHandler()

    var todayTasks: [UserTask] = []
    var todayEvents: [EventOccurrence] = []
    var greeting: String = ""

    init(
        taskFetcher: UserTaskFetcherService,
        taskEditor: TaskEditorService,
        eventFetcher: EventFetcherService,
        locationService: LocationService,
        adManager: AdMobManager
    ) {
        self.taskFetcher = taskFetcher
        self.taskEditor = taskEditor
        self.eventFetcher = eventFetcher
        self.locationService = locationService
        self.adManager = adManager
        
        locationService.startUpdatingLocation()
        
        observeRepositories()
        updateGreeting()
    }

    private func observeRepositories() {
//        taskRepository.tasks.observe(owner: self, fireNow: false) { [weak self] tasks in
//            let today = Calendar.current.startOfDay(for: Date())
//            let filtered = tasks.filter {
//                if let due = $0.dueDate {
//                    return due <= today && !$0.isCompleted
//                } else {
//                    return !$0.isCompleted
//                }
//            }
//            DispatchQueue.main.async {
//                self?.todayTasks = filtered
//                self?.state = filtered.isEmpty ? .empty : .loaded
//            }
//        }
    }
    
    func fetchData() async {
        do {
            let tasks = try await taskFetcher.fetchTasks()
            let today = Date().startOfDay
            
            let filtered = tasks.filter {
                if let due = $0.dueDate {
                    return due <= today && !$0.isCompleted
                } else {
                    return !$0.isCompleted
                }
            }
            DispatchQueue.main.async {
                self.todayTasks = filtered
                self.state = filtered.isEmpty ? .empty : .loaded
            }
            
            let occurrences = try await eventFetcher.fetchOccurrences()
            guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else { return }
            handleOccurrences(occurrences, in: today...tomorrow)
        } catch {
            await errorHandler.handle(error)
        }
    }
    
    func handleOccurrences(_ occurrences: [EventOccurrence], in range: ClosedRange<Date>) {
        do {
            let today = Calendar.current.startOfDay(for: Date())
            
            let eventsWithRecurringOcc = try EventOccurrenceService.generate(rawOccurrences: occurrences, in: range)
            
            let filtered = eventsWithRecurringOcc.filter {
                Calendar.current.isDate($0.startDate, inSameDayAs: today)
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
        guard let id = task.id else { return }
        var updated = task
        updated.isCompleted.toggle()
        Task {
            try? await taskEditor.update(makeInput(task: updated), id: id)
            await fetchData()
        }
    }
    
    private func updateGreeting(date: Date = Date()) {
        let hour = Calendar.current.component(.hour, from: date)
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
