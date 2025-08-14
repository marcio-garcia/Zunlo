//
//  EventRepositoryFactory.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation
import SwiftData
import SupabaseSDK

final class EventRepositoryFactory {
    static func make(
        supabase: SupabaseSDK,
        authManager: AuthManager,
        localDB: DatabaseActor
    ) -> EventRepository {
        let eventRemoteStore: EventRemoteStore
        let eventLocalStore: EventLocalStore
        let recurrenceRuleRemoteStore: RecurrenceRuleRemoteStore
        let recurrenceRuleLocalStore: RecurrenceRuleLocalStore
        let eventOverrideRemoteStore:EventOverrideRemoteStore
        let eventOverrideLocalStore: EventOverrideLocalStore
        
        eventRemoteStore = SupabaseEventRemoteStore(supabase: supabase, auth: authManager)
        eventLocalStore = RealmEventLocalStore(db: localDB, auth: authManager)

        recurrenceRuleRemoteStore = SupabaseRecurrenceRuleRemoteStore(supabase: supabase, auth: authManager)
        recurrenceRuleLocalStore = RealmRecurrenceRuleLocalStore(db: localDB)

        eventOverrideRemoteStore = SupabaseEventOverrideRemoteStore(supabase: supabase, auth: authManager)
        eventOverrideLocalStore = RealmEventOverrideLocalStore(db: localDB)

        return EventRepository(
            eventLocalStore: eventLocalStore,
            eventRemoteStore: eventRemoteStore,
            recurrenceRuleLocalStore: recurrenceRuleLocalStore,
            recurrenceRuleRemoteStore: recurrenceRuleRemoteStore,
            eventOverrideLocalStore: eventOverrideLocalStore,
            eventOverrideRemoteStore: eventOverrideRemoteStore
        )
    }
}
