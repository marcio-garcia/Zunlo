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
            try await remoteStore.save(event.toRemote())
            try localStore.save(event.toLocal())
            await fetchAll()
        } catch {
            print("Failed to save events remotely: \(error)")
            throw error
        }
    }

    func update(_ event: Event) async throws {
        do {
            try await remoteStore.update(event.toRemote())
            try localStore.update(event.toLocal())
            await fetchAll()
        } catch {
            print("Failed to update events remotely: \(error)")
            throw error
        }
    }

    func delete(_ event: Event) async throws {
        do {
            try await remoteStore.delete(event.toRemote())
            try localStore.delete(event.toLocal())
            await fetchAll()
        } catch {
            print("Failed to delete events remotely: \(error)")
            throw error
        }
    }

    func deleteAllEvents() async throws {
        do {
            try await remoteStore.deleteAll()
            try localStore.deleteAll()
            await fetchAll()
        } catch {
            print("Failed to delete all events remotely: \(error)")
            throw error
        }
    }
}
