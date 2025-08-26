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
        auth: AuthProviding,
        supabase: SupabaseSDK,
        localDB: DatabaseActor
    ) -> EventRepository {
        let eventRemoteStore: EventRemoteStore
        let eventLocalStore: EventLocalStore
        let recurrenceRuleRemoteStore: RecurrenceRuleRemoteStore
        let recurrenceRuleLocalStore: RecurrenceRuleLocalStore
        let eventOverrideRemoteStore:EventOverrideRemoteStore
        let eventOverrideLocalStore: EventOverrideLocalStore
        
        eventRemoteStore = SupabaseEventRemoteStore(supabase: supabase, auth: auth)
        eventLocalStore = RealmEventLocalStore(db: localDB, auth: auth)

        recurrenceRuleRemoteStore = SupabaseRecurrenceRuleRemoteStore(supabase: supabase, auth: auth)
        recurrenceRuleLocalStore = RealmRecurrenceRuleLocalStore(db: localDB)

        eventOverrideRemoteStore = SupabaseEventOverrideRemoteStore(supabase: supabase, auth: auth)
        eventOverrideLocalStore = RealmEventOverrideLocalStore(db: localDB)

        return EventRepository(
            auth: auth,
            eventLocalStore: eventLocalStore,
            eventRemoteStore: eventRemoteStore,
            recurrenceRuleLocalStore: recurrenceRuleLocalStore,
            recurrenceRuleRemoteStore: recurrenceRuleRemoteStore,
            eventOverrideLocalStore: eventOverrideLocalStore,
            eventOverrideRemoteStore: eventOverrideRemoteStore
        )
    }
}
