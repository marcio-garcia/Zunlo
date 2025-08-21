//
//  TodayViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/18/25.
//

import SwiftUI
import MiniSignalEye
import AdStack
import Supabase

final class TodayViewModel: ObservableObject, @unchecked Sendable {
    @Published var state: ViewState = .loading
    @Published var weather: WeatherInfo?
    @Published var eventEditHandler = EventEditHandler()
    @Published var isSyncingDB = false
    
    private let appState: AppState
    
    @MainActor let errorHandler = ErrorHandler()

    var todayTasks: [UserTask] = []
    var todayEvents: [EventOccurrence] = []
    var greeting: String = ""
    
    var taskRepo: UserTaskRepository {
        appState.userTaskRepository!
    }
    var eventRepo: EventRepository {
        appState.eventRepository!
    }
    var locationService: LocationService {
        appState.locationService!
    }
    var adManager: AdMobManager {
        appState.adManager!
    }
    
    init(appState: AppState) {
        self.appState = appState
        appState.locationService?.startUpdatingLocation()
        
        observeRepositories()
        updateGreeting()
    }

    private func observeRepositories() {
        taskRepo.lastTaskAction.observe(owner: self, queue: DispatchQueue.main, fireNow: false) { [weak self] action in
            if case .fetch(let tasks) = action {
                
                let today = Date().startOfNextDay()
                
                let filtered = tasks.filter {
                    guard $0.deletedAt == nil else { return false }
                    guard let due = $0.dueDate else { return !$0.isCompleted }
                    return due <= today && !$0.isCompleted
                }
                
                let isEmpty = filtered.isEmpty
                self?.todayTasks = filtered
                
                DispatchQueue.main.async {
                    self?.state = isEmpty ? .empty : .loaded
                }

            }
        }
        
        eventRepo.lastEventAction.observe(owner: self, queue: DispatchQueue.main, fireNow: false) { [weak self] action in
            if case .fetch(let occ) = action {
                let today = Date().startOfDay
                let tomorrow = today.startOfNextDay()
                self?.handleOccurrences(occ, in: today..<tomorrow)
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
    
    func handleOccurrences(_ occurrences: [EventOccurrence], in range: Range<Date>) {
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
            try? await taskEditor.upsert(makeInput(task: updated))
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
            id: task.id,
            userId: task.userId,
            title: task.title,
            notes: task.notes,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted,
            priority: task.priority,
            parentEventId: task.parentEventId,
            tags: task.tags,
            reminderTriggers: task.reminderTriggers,
            deleteAt: task.deletedAt
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

extension TodayViewModel {
    func syncDB() async {
        guard (appState.authManager?.userId) != nil else {
            state = .error("Need authentication")
            fatalError("DB sync needs authentication")
        }
        
        guard let localDB = appState.localDB else { return }
        
        await MainActor.run { self.isSyncingDB = true }
        
        let sync = SyncCoordinator(db: localDB, supabase: appState.supabaseClient!)
        
        let rowsAffected = await sync.syncAllOnLaunch()
        await MainActor.run { self.isSyncingDB = false }
        
        if rowsAffected > 0 {
            await fetchData()
        }
    }
}
