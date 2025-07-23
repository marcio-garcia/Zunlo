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
        authManager: AuthManager
    ) -> EventRepository {
        let eventRemoteStore: EventRemoteStore
        let eventLocalStore: EventLocalStore
        let recurrenceRuleRemoteStore: RecurrenceRuleRemoteStore
        let recurrenceRuleLocalStore: RecurrenceRuleLocalStore
        let eventOverrideRemoteStore:EventOverrideRemoteStore
        let eventOverrideLocalStore: EventOverrideLocalStore
        
        eventRemoteStore = SupabaseEventRemoteStore(supabase: supabase, authManager: authManager)
        eventLocalStore = RealmEventLocalStore()

        recurrenceRuleRemoteStore = SupabaseRecurrenceRuleRemoteStore(supabase: supabase, authManager: authManager)
        recurrenceRuleLocalStore = RealmRecurrenceRuleLocalStore()

        eventOverrideRemoteStore = SupabaseEventOverrideRemoteStore(supabase: supabase, authManager: authManager)
        eventOverrideLocalStore = RealmEventOverrideLocalStore()

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
