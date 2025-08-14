//
//  SyncCoordinator.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Supabase

final class SyncCoordinator {
    private let events: EventSyncEngine
    private let rules: RecurrenceRuleSyncEngine
    private let overrides: EventOverrideSyncEngine
    private let userTasks: UserTaskSyncEngine

    init(db: DatabaseActor, supabase: SupabaseClient) {
        self.events = EventSyncEngine(db: db, supabase: supabase)
        self.rules = RecurrenceRuleSyncEngine(db: db, supabase: supabase)
        self.overrides = EventOverrideSyncEngine(db: db, supabase: supabase)
        self.userTasks = UserTaskSyncEngine(db: db, supabase: supabase)
    }

    func syncAllOnLaunch() async {
        await events.syncNow()
        await rules.syncNow()       // depends on events
        await overrides.syncNow()   // depends on events, optional after rules
        await userTasks.syncNow()
    }
}
