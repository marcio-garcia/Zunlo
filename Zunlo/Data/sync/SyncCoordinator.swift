//
//  SyncCoordinator.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import Supabase

struct SyncSummary {
    let taskReport: SyncReport
    
    internal init(taskReport: SyncReport = .zero) {
        self.taskReport = taskReport
    }
}

final class SyncCoordinator {
    private let supabase: SupabaseClient
    
    private let events: EventSyncEngine
    private let rules: RecurrenceRuleSyncEngine
    private let overrides: EventOverrideSyncEngine
    private let userTasks: UserTaskSyncEngine
    
    var eventsPushed: Int = 0
    var eventsPulled: Int = 0
    var rulesPushed: Int = 0
    var rulesPulled: Int = 0
    var overridesPushed: Int = 0
    var overridesPulled: Int = 0
    var taskReport: SyncReport = .zero
    
    init(db: DatabaseActor, supabase: SupabaseClient) {
        self.supabase = supabase
        let syncApi = SupabaseSyncAPI(client: supabase)
        self.events = EventSyncEngine(db: db, api: syncApi)
        self.rules = RecurrenceRuleSyncEngine(db: db, api: syncApi)
        self.overrides = EventOverrideSyncEngine(db: db, api: syncApi)
        self.userTasks = UserTaskSyncEngine(db: db, api: syncApi)
        
        Task {
//            try await db.markEventDirty(UUID(uuidString: "C74A7FDA-8EB0-4E18-B958-D7E9AF279C3B")!)
//            try await db.markEventsClean(UUID(uuidString: "C74A7FDA-8EB0-4E18-B958-D7E9AF279C3B")!)
//            try await db.markAllEventsDirty()
//            try await db.undeleteEvent(id: UUID(uuidString: "27c828d2-8d0f-4ae7-a616-c43adb4d65b5")!, userId: UUID(uuidString: "2d2c47af-3923-4524-8e85-be91371483f5")!)
            
            await supabase.auth.onAuthStateChange { event, session in
                print("Auth event:", event)
                if let token = session?.accessToken {
                    print("Now using USER JWT:", token.prefix(16), "…")
                }
            }
        }
    }

    func syncAllOnLaunch() async throws -> SyncSummary {
        do {
            let session = try await supabase.auth.session
            guard !session.isExpired else {
                print("⚠️ Sync aborted: no user session (using anon key).")
                return SyncSummary()
            }
            print("Sync with user:", session.user.id)
            print("✅ Using USER JWT:", session.accessToken.prefix(16), "…")
        } catch {
            print("Auth error before sync. \(error.localizedDescription)")
            return SyncSummary()
        }
        
//        (eventsPushed, eventsPulled) = await events.syncNow()
//        (rulesPushed, rulesPulled)  = await rules.syncNow()       // depends on events
//        (overridesPushed, overridesPulled) = await overrides.syncNow()   // depends on events, optional after rules
        taskReport = try await userTasks.syncNow()
        return SyncSummary(taskReport: taskReport)
    }
}
