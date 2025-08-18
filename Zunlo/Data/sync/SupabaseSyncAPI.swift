//
//  SupabaseSyncAPI.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation
import Supabase

extension Data {
    func decodeSupabase<T: Decodable>() throws -> T {
        return try JSONDecoder.supabaseMicroFirst().decode(T.self, from: self)
    }
}

public struct SupabaseSyncAPI: SyncAPI {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Events
    public func insertEventsReturning(_ batch: [EventRemote]) async throws -> [EventRemote] {
        let r = try await client.from("events").insert(batch).select().execute()
        let result: [EventRemote] = try r.data.decodeSupabase()
        return result
    }
    public func updateEventIfVersionMatches(_ dto: EventRemote) async throws -> EventRemote? {
        guard let v = dto.version else { return nil }
        let r = try await client.from("events").update(dto).eq("id", value: dto.id).eq("version", value: v).select().execute()
        let result: [EventRemote] = try r.data.decodeSupabase()
        return result.first
    }
    public func fetchEvent(id: UUID) async throws -> EventRemote? {
        let r = try await client.from("events").select().eq("id", value: id).limit(1).execute()
        let result: [EventRemote] = try r.data.decodeSupabase()
        return result.first
    }
    
    public func fetchEventsToSync(sinceTimestamp: String, sinceID: UUID?, pageSize: Int) async throws -> [EventRemote] {
        let data = try await client
            .from("events")
            .select()
            .or("updated_at.gt.\(sinceTimestamp),and(updated_at.eq.\(sinceTimestamp),id.gt.\(sinceID?.uuidString ?? "00000000-0000-0000-0000-000000000000"))")
            .order("updated_at", ascending: true)
            .order("id", ascending: true)
            .limit(pageSize)
            .execute()
            .data
        
        let rows: [EventRemote] = try data.decodeSupabase()
        return rows
    }

    // MARK: - Recurrence rules
    public func insertRecurrenceRulesReturning(_ batch: [RecurrenceRuleRemote]) async throws -> [RecurrenceRuleRemote] {
        let r = try await client.from("recurrence_rules").insert(batch).select().execute()
        let result: [RecurrenceRuleRemote] = try r.data.decodeSupabase()
        return result
    }
    public func updateRecurrenceRuleIfVersionMatches(_ dto: RecurrenceRuleRemote) async throws -> RecurrenceRuleRemote? {
        let r = try await client.from("recurrence_rules")
            .update(dto).eq("id", value: dto.id).eq("version", value: dto.version ?? -1).select().execute()
        let result: [RecurrenceRuleRemote] = try r.data.decodeSupabase()
        return result.first
    }
    public func fetchRecurrenceRule(id: UUID) async throws -> RecurrenceRuleRemote? {
        let r = try await client.from("recurrence_rules").select().eq("id", value: id).limit(1).execute()
        let result: [RecurrenceRuleRemote] = try r.data.decodeSupabase()
        return result.first
    }
    
    public func fetchRecurrenceRulesToSync(sinceTimestamp: String, sinceID: UUID?, pageSize: Int) async throws -> [RecurrenceRuleRemote] {
        let data = try await client
            .from("recurrence_rules")
            .select()
            .or("updated_at.gt.\(sinceTimestamp),and(updated_at.eq.\(sinceTimestamp),id.gt.\(sinceID?.uuidString ?? "00000000-0000-0000-0000-000000000000"))")
            .order("updated_at", ascending: true)
            .order("id", ascending: true)
            .limit(pageSize)
            .execute()
            .data
        
        let rows: [RecurrenceRuleRemote] = try data.decodeSupabase()
        return rows
    }

    // MARK: - Event overrides
    public func insertEventOverridesReturning(_ batch: [EventOverrideRemote]) async throws -> [EventOverrideRemote] {
        let r = try await client.from("event_overrides").insert(batch).select().execute()
        let result: [EventOverrideRemote] = try r.data.decodeSupabase()
        return result
    }
    public func updateEventOverrideIfVersionMatches(_ dto: EventOverrideRemote) async throws -> EventOverrideRemote? {
        let r = try await client.from("event_overrides")
            .update(dto).eq("id", value: dto.id).eq("version", value: dto.version ?? -1).select().execute()
        let result: [EventOverrideRemote] = try r.data.decodeSupabase()
        return result.first
    }
    public func fetchEventOverride(id: UUID) async throws -> EventOverrideRemote? {
        let r = try await client.from("event_overrides").select().eq("id", value: id).limit(1).execute()
        let result: [EventOverrideRemote] = try r.data.decodeSupabase()
        return result.first
    }
    
    public func fetchEventOverridesToSync(sinceTimestamp: String, sinceID: UUID?, pageSize: Int) async throws -> [EventOverrideRemote] {
        let data = try await client
            .from("recurrence_rules")
            .select()
            .or("updated_at.gt.\(sinceTimestamp),and(updated_at.eq.\(sinceTimestamp),id.gt.\(sinceID?.uuidString ?? "00000000-0000-0000-0000-000000000000"))")
            .order("updated_at", ascending: true)
            .order("id", ascending: true)
            .limit(pageSize)
            .execute()
            .data
        
        let rows: [EventOverrideRemote] = try data.decodeSupabase()
        return rows
    }

    // MARK: - Tasks
    public func insertUserTasksReturning(_ batch: [UserTaskRemote]) async throws -> [UserTaskRemote] {
        let r = try await client.from("tasks").insert(batch).select().execute()
        let result: [UserTaskRemote] = try r.data.decodeSupabase()
        return result
    }
    public func updateUserTaskIfVersionMatches(_ dto: UserTaskRemote) async throws -> UserTaskRemote? {
        let r = try await client.from("tasks")
            .update(dto).eq("id", value: dto.id).eq("version", value: dto.version ?? -1).select().execute()
        let result: [UserTaskRemote] = try r.data.decodeSupabase()
        return result.first
    }
    public func fetchUserTask(id: UUID) async throws -> UserTaskRemote? {
        let r = try await client.from("tasks").select().eq("id", value: id).limit(1).execute()
        let result: [UserTaskRemote] = try r.data.decodeSupabase()
        return result.first
    }
    
    public func fetchUserTasksToSync(sinceTimestamp: String, sinceID: UUID?, pageSize: Int) async throws -> [UserTaskRemote] {
        let data = try await client
            .from("tasks")
            .select()
            .or("updated_at.gt.\(sinceTimestamp),and(updated_at.eq.\(sinceTimestamp),id.gt.\(sinceID?.uuidString ?? "00000000-0000-0000-0000-000000000000"))")
            .order("updated_at", ascending: true)
            .order("id", ascending: true)
            .limit(pageSize)
            .execute()
            .data
        
        let rows: [UserTaskRemote] = try data.decodeSupabase()
        return rows
    }
}


