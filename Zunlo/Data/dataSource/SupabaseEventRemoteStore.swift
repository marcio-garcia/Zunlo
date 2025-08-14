//
//  SupabaseEventRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/29/25.
//

import Foundation
import SupabaseSDK

enum StoreError: Error, LocalizedError {
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidData(let field): return "Invalid input data: \(field)"
        }
    }
}

final class SupabaseEventRemoteStore: EventRemoteStore {
    private let tableName = "events"
    private var supabase: SupabaseSDK
    private var auth: AuthProviding

    private var authToken: String? { auth.accessToken }
    private var database: SupabaseDatabase { supabase.database(authToken: authToken) }

    init(supabase: SupabaseSDK, auth: AuthProviding) {
        self.supabase = supabase
        self.auth = auth
    }

    func fetchAll() async throws -> [EventRemote] {
        try await database.fetch(from: tableName, as: EventRemote.self, query: ["select": "*"])
    }
    
    func fetchOccurrences() async throws -> [EventOccurrenceResponse] {
        do {
            return try await database.fetchOccurrences(as: EventOccurrenceResponse.self)
        } catch let error as SupabaseServiceError {
            if case let .serverError(statusCode, _, _) = error, statusCode == 401 {
                guard let session = try await auth.refreshSession(refreshToken: nil) else {
                    throw error
                }
                database.authToken = session.accessToken
                return try await database.fetchOccurrences(as: EventOccurrenceResponse.self)
            }
            throw error
        } catch {
            throw error
        }
    }

    func save(_ event: EventRemote) async throws -> [EventRemote] {
        // Only nil the ID if creating a new record and let Supabase/DB handle it
        var ev = event
        ev.user_id = nil
        ev.created_at = nil
        return try await database.insert(ev, into: tableName)
    }

    func update(_ event: EventRemote) async throws -> [EventRemote] {
        var ev = event
        ev.user_id = nil
        ev.created_at = nil
        return try await database.update(ev, in: tableName, filter: ["id": "eq.\(event.id.uuidString)"])
    }

    func delete(id: UUID) async throws -> [EventRemote] {
        return try await database.delete(from: tableName, filter: ["id": "eq.\(id)"])
    }

    func deleteAll(for userId: UUID) async throws -> [EventRemote] {
        try await database.delete(from: tableName, filter: ["user_id": "eq.\(userId.uuidString)"])
    }
    
    func splitRecurringEvent(
        originalEventId: UUID,
        splitDate: Date,
        newEvent: Event
    ) async throws -> SplitRecurringEventResponse {
        
        guard let userId = newEvent.userId else {
            throw StoreError.invalidData("userId")
        }
        
        let data = SplitRecurringEventRemote.NewEventData(
            userId: userId,
            title: newEvent.title,
            description: newEvent.notes,
            startDatetime: newEvent.startDate,
            endDatetime: newEvent.endDate,
            isRecurring: newEvent.isRecurring,
            location: newEvent.location,
            color: newEvent.color,
            reminderTriggers: newEvent.reminderTriggers
        )
        let split = SplitRecurringEventRemote(
            originalEventId: originalEventId,
            splitFromDate: splitDate,
            newEventData: data
        )

        return try await database.splitRecurringEvent(split)
    }
}
