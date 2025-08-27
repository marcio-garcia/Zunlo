//
//  SyncCoordinator.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import Supabase

struct SyncSummary {
    let eventReport: SyncReport
    let overrideReport: SyncReport
    let ruleReport: SyncReport
    let taskReport: SyncReport
    
    internal init(
        eventReport: SyncReport = .zero,
        ruleReport: SyncReport = .zero,
        overrideReport: SyncReport = .zero,
        taskReport: SyncReport = .zero
    ) {
        self.eventReport = eventReport
        self.ruleReport = ruleReport
        self.overrideReport = overrideReport
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
        
        let eventRunner = events.makeRunner()
        let ruleRunner = rules.makeRunner()
        let overrideRunner = overrides.makeRunner()
        let taskRunner  = userTasks.makeRunner()
        
        let eventReport = await eventRunner.syncNow()
        let ruleReport  = await ruleRunner.syncNow()
        let overrideReport = await overrideRunner.syncNow()
        let taskReport = await taskRunner.syncNow()
        
        return SyncSummary(
            eventReport: eventReport,
            ruleReport: ruleReport,
            overrideReport: overrideReport,
            taskReport: taskReport
        )
    }
}
