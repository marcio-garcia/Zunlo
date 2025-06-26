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
    @Published private(set) var events: [EventEntity] = []

    private var modelContext: ModelContext
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 60
    private let supabase: SupabaseSDK
    
    init(modelContext: ModelContext) {
        let config = SupabaseConfig(anonKey: EnvConfig.shared.apiKey, baseURL: URL(string: EnvConfig.shared.apiBaseUrl)!)
        supabase = SupabaseSDK(config: config)
        self.modelContext = modelContext
        fetchLocalEvents()
        startAutoRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func fetchLocalEvents() {
        let fetchDescriptor = FetchDescriptor<EventEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            events = try modelContext.fetch(fetchDescriptor)
        } catch {
            print("Failed to fetch events: \(error)")
            events = []
        }
    }

    func saveEvents(_ newEvents: [EventEntity]) {
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

    // MARK: - Supabase Fetch (replace with your real endpoint)
    func fetchEventsFromSupabase() async {
        // Replace with your real URL
        guard let url = URL(string: "https://YOUR_PROJECT.supabase.co/rest/v1/events?select=*") else { return }
        var request = URLRequest(url: url)
        request.addValue("Bearer YOUR_SUPABASE_ANON_KEY", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let remoteEvents = try JSONDecoder().decode([Event].self, from: data)
            let localEvents = remoteEvents.map { $0.toEventEntity() }
            saveEvents(localEvents)
        } catch {
            print("Supabase fetch error: \(error)")
        }
    }

    func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { await self?.fetchEventsFromSupabase() }
        }
        Task { await self.fetchEventsFromSupabase() }
    }

    // MARK: - Events from Today
    func eventsStartingFromToday() -> [EventEntity] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return events.filter { $0.dueDate >= startOfToday }
    }
}

