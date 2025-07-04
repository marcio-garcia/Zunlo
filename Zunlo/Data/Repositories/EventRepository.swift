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
            let domainEvents = localEvents.compactMap { $0.toDomain() }
            print(domainEvents)
            self.events = domainEvents
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

extension EventRepository {
    /// All unique days with at least one event (including recurrences)
    func allEventDates(in range: ClosedRange<Date>) -> [Date] {
        events.allEventDates(in: range)
    }
    
    /// All events that occur on the given day (handles recurrences/exceptions)
    func events(on date: Date) -> [Event] {
        events.filter { $0.occurs(on: date) }
    }
    
    /// Is there any event on this day?
    func containsEvent(on date: Date) -> Bool {
        !events(on: date).isEmpty
    }
}

extension EventRepository {
    /// Save or update an event, handling all cases (new, edit, edit single instance of recurring).
    /// - Parameters:
    ///   - eventToEdit: If editing, the event being edited (else nil for new).
    ///   - parentEventForException: If present, this is an "edit only this instance" operation.
    ///   - overrideDate: For "edit only this instance", the original occurrence date being overridden.
    ///   - newTitle: The updated title from the form.
    ///   - newDate: The new date from the form.
    ///   - recurrence: The updated recurrence rule from the form.
    ///   - isComplete: Whether the event is complete (optional; defaults to false).
    func saveEvent(
        eventToEdit: Event?,
        parentEventForException: Event?,
        overrideDate: Date?,
        newTitle: String,
        newDate: Date,
        recurrence: RecurrenceRule,
        isComplete: Bool = false
    ) async throws {
        if let parent = parentEventForException, let originalInstanceDate = overrideDate {
            // EDIT ONLY THIS INSTANCE
            // 1. Update parent's exceptions (skip this date)
            var updatedParent = parent
            updatedParent.exceptions.append(originalInstanceDate)
            try await update(updatedParent)
            // 2. Save new single-instance event (could be at new time)
            let newEvent = Event(
                id: nil,
                userId: nil,
                title: newTitle,
                createdAt: nil,
                dueDate: newDate,
                recurrence: .none,
                exceptions: [],
                isComplete: isComplete
            )
            try await save(newEvent)
        } else if let editing = eventToEdit {
            // EDIT EXISTING EVENT
            let updated = Event(
                id: editing.id,
                userId: editing.userId,
                title: newTitle,
                createdAt: editing.createdAt,
                dueDate: newDate,
                recurrence: recurrence,
                exceptions: editing.exceptions,
                isComplete: isComplete
            )
            try await update(updated)
        } else {
            // NEW EVENT
            let newEvent = Event(
                id: nil,
                userId: nil,
                title: newTitle,
                createdAt: nil,
                dueDate: newDate,
                recurrence: recurrence,
                exceptions: [],
                isComplete: isComplete
            )
            try await save(newEvent)
        }
    }
}
