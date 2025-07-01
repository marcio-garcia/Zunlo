//
//  EventRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

final class EventRepository: ObservableObject {
    @Published private(set) var events: [Event] = []

    private let localStore: EventLocalStore
    private let remoteStore: EventRemoteStore

    init(localStore: EventLocalStore, remoteStore: EventRemoteStore) {
        self.localStore = localStore
        self.remoteStore = remoteStore
    }

    @MainActor
    func fetchAll() async {
        do {
            let localEvents = try localStore.fetch()
            self.events = localEvents.compactMap { $0.toDomain() }
        } catch {
            self.events = []
            print("Failed to fetch local events: \(error)")
        }
    }

    func save(_ event: Event) async throws {
        do {
            let inserted = try await remoteStore.save(event.toRemote())
            for event in inserted {
                try await localStore.save(event.toLocal())
            }
            await fetchAll()
        } catch {
            print("Failed to save events remotely: \(error)")
            throw error
        }
    }

    func update(_ event: Event) async throws {
        do {
            let updated = try await remoteStore.update(event.toRemote())
            for event in updated {
                try await localStore.update(event.toLocal())
            }
            await fetchAll()
        } catch {
            print("Failed to update events remotely: \(error)")
            throw error
        }
    }

    func delete(_ event: Event) async throws {
        do {
            let deleted = try await remoteStore.delete(event.toRemote())
            for event in deleted {
                try await localStore.delete(event.toLocal())
            }
            await fetchAll()
        } catch {
            print("Failed to delete events remotely: \(error)")
            throw error
        }
    }

    func deleteAllEvents(userId: UUID) async throws {
        do {
            _ = try await remoteStore.deleteAll()
            try await localStore.deleteAll(for: userId)
            await fetchAll()
        } catch {
            print("Failed to delete all events remotely: \(error)")
            throw error
        }
    }
    
    func synchronize() async throws {
        do {
            let all = try await remoteStore.fetch()
            try await localStore.deleteAll()
            for event in all {
                try await localStore.save(event.toLocal())
            }
        } catch {
            throw error
        }
    }
}
