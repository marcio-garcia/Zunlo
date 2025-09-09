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
        let eventLocalStore: EventLocalStore = RealmEventLocalStore(db: localDB)
        let recurrenceRuleLocalStore: RecurrenceRuleLocalStore = RealmRecurrenceRuleLocalStore(db: localDB)
        let eventOverrideLocalStore: EventOverrideLocalStore = RealmEventOverrideLocalStore(db: localDB)

        return EventRepository(
            auth: auth,
            eventLocalStore: eventLocalStore,
            recurrenceRuleLocalStore: recurrenceRuleLocalStore,
            eventOverrideLocalStore: eventOverrideLocalStore
        )
    }
}
