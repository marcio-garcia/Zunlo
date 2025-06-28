//
//  EventRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation
import SwiftData
import SupabaseSDK

@MainActor
class EventRepository: ObservableObject {
    @Published private(set) var events: [Event] = []

    private unowned let authManager: AuthManager
    
    private var modelContext: ModelContext
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 5
    private let supabase: SupabaseSDK
    
    init(modelContext: ModelContext, authManager: AuthManager) {
        let config = SupabaseConfig(anonKey: EnvConfig.shared.apiKey, baseURL: URL(string: EnvConfig.shared.apiBaseUrl)!)
        supabase = SupabaseSDK(config: config)
        self.modelContext = modelContext
        self.authManager = authManager
        startAutoRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func fetchLocalEvents() {
        print("Repo address: \(Unmanaged.passUnretained(self).toOpaque())")

        let fetchDescriptor = FetchDescriptor<EventLocal>(
            sortBy: [SortDescriptor(\.dueDate, order: .forward)]
        )
        do {
            let localEvents = try modelContext.fetch(fetchDescriptor)
            print("Fetched events: \(localEvents.count)")
            DispatchQueue.main.async {
                print("Assigning events on main thread? \(Thread.isMainThread)")
                self.events = localEvents.compactMap({ $0.toDomain() })
                print("Domain events: \(self.events.count)")
            }
            
            
        } catch {
            print("Failed to fetch events: \(error)")
            events = []
        }
    }

    func saveLocalEvents(_ newEvents: [EventLocal]) {
        var updated = false
        for event in newEvents {
            if !events.contains(where: { $0.id == event.id }) {
                modelContext.insert(event)
                updated = true
            }
        }
        if updated {
            do {
                try modelContext.save()
                fetchLocalEvents()
            } catch {
                print("Failed to save events: \(error)")
            }
        }
    }
    
    func deleteAllLocalEvents() throws {
        let fetchDescriptor = FetchDescriptor<EventLocal>()
        let allTasks = try modelContext.fetch(fetchDescriptor)
        
        allTasks.forEach { modelContext.delete($0) }
        
        try modelContext.save()
    }

    func clearCache() {
        events.forEach {
            modelContext.delete($0.toLocal())
        }
        do {
            try modelContext.save()
            fetchLocalEvents()
        } catch {
            print("Failed to clear events: \(error)")
        }
    }

    func fetchEventsFromSupabase() async {
        guard let auth = authManager.auth else { return }
        
        do {
            let remoteEvents = try await supabase.database(
                authToken: auth.token.accessToken
            ).fetch(from: "events",
                    as: EventRemote.self,
                    query: ["select": "*"])
            
            let localEvents = remoteEvents.map { $0.toLocal() }
            saveLocalEvents(localEvents)
        } catch {
            print("Supabase fetch error: \(error)")
        }
    }
    
    func addEvent(_ event: Event) async throws {
        guard let auth = authManager.auth else { return }
        
        do {
            var remoteEvent = event.toRemote()
            remoteEvent.id = nil
            remoteEvent.userId = nil
            remoteEvent.createdAt = nil
            try await supabase.database(authToken: auth.token.accessToken).insert(remoteEvent, into: "events")
        } catch {
            throw error
        }
    }

    func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { await self?.fetchEventsFromSupabase() }
        }
        // Just for testing - remove it later
//        try? deleteAllLocalEvents()
        
        Task { await self.fetchEventsFromSupabase() }
    }

    // MARK: - Events from Today
    func eventsStartingFromToday() -> [Event] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return events.filter { $0.dueDate >= startOfToday }
    }
}

