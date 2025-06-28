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
    @Published private(set) var events: [EventLocal] = []

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
        fetchLocalEvents()
        startAutoRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func fetchLocalEvents() {
        let fetchDescriptor = FetchDescriptor<EventLocal>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            events = try modelContext.fetch(fetchDescriptor)
        } catch {
            print("Failed to fetch events: \(error)")
            events = []
        }
    }

    func saveEvents(_ newEvents: [EventLocal]) {
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

    func clearCache() {
        for event in events {
            modelContext.delete(event)
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
            saveEvents(localEvents)
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
//        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
//            Task { await self?.fetchEventsFromSupabase() }
//        }
        Task { await self.fetchEventsFromSupabase() }
    }

    // MARK: - Events from Today
    func eventsStartingFromToday() -> [EventLocal] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return events.filter { $0.dueDate >= startOfToday }
    }
}

