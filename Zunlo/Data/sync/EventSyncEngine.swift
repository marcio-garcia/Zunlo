//
//  EventSyncEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import RealmSwift
import Supabase

final class EventSyncEngine {
    private let realm: Realm
    private let supabase: SupabaseClient
    private let pageSize = 500

    private let lastPullKey = "events.lastPulledAt" // UserDefaults key

    init(realm: Realm = try! Realm(), supabase: SupabaseClient) {
        self.realm = realm
        self.supabase = supabase
    }

    // MARK: - Public API
    func syncNow() async {
        do {
            try await pushDirty()
            try await pullSinceCursor()
        } catch {
            // Log and let a retry/backoff handle it later
            print("Event sync error:", error)
        }
    }

    // MARK: - Push
    private func pushDirty() async throws {
        let dirty = Array(realm.objects(EventLocal.self).where { $0.needsSync == true })
        guard !dirty.isEmpty else { return }

        let batch = dirty.map({ EventRemote(local: $0) })

        // Upsert by id (server trigger sets updated_at)
        // Adjust to your Supabase Swift version if method signatures differ:
        _ = try await supabase
            .from("events")
            .upsert(batch, onConflict: "id")
            .execute()

        try realm.write {
            dirty.forEach { $0.needsSync = false }
        }
    }

    // MARK: - Pull
    private func pullSinceCursor() async throws {
        var since = UserDefaults.standard.string(forKey: lastPullKey)
        // first-time: pull everything since epoch
        if since == nil { since = "1970-01-01T00:00:00Z" }

        var fetchedAny = false
        var lastServerUpdatedAt: Date?

        repeat {
            let rows: [EventRemote] = try await supabase
                .from("events")
                .select()
                .gt("updated_at", value: since!)
                .order("updated_at", ascending: true)
                .limit(pageSize)
                .execute()
                .value

            fetchedAny = !rows.isEmpty

            if fetchedAny {
                try realm.write {
                    for dto in rows {
                        // If we have a local dirty edit we haven't pushed yet,
                        // skip applying remote to avoid stomping (trade-off in v1).
                        if let existing = realm.object(ofType: EventLocal.self, forPrimaryKey: dto.id),
                           existing.needsSync == true {
                            continue
                        }

                        let obj = realm.object(ofType: EventLocal.self, forPrimaryKey: dto.id)
                            ?? EventLocal(value: ["id": dto.id])

                        obj.getUpdateFields(dto)
                        obj.deletedAt = dto.deleted_at
                        obj.needsSync = false

                        // Optional: if deletedAt present, decide whether to purge now or keep tombstone
                        // if let _ = dto.deleted_at { realm.delete(obj) }
                        realm.add(obj, update: .modified)
                    }
                }

                if let last = rows.last?.updated_at {
                    lastServerUpdatedAt = last
                    since = iso8601(last)
                }
            }
        } while fetchedAny

        if let last = lastServerUpdatedAt {
            UserDefaults.standard.set(iso8601(last), forKey: lastPullKey)
        }
    }
}

// MARK: - ISO8601 helpers
private func iso8601(_ date: Date) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.string(from: date)
}
