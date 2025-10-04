//
//  SyncCoordinator.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import Supabase
import LoggingKit

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
    
    var eventRowsAffected: Int {
        eventReport.pulled + eventReport.pushed + eventReport.conflicts
    }
    
    var overrideRowsAffected: Int {
        overrideReport.pulled + overrideReport.pushed + overrideReport.conflicts
    }
    
    var ruleRowsAffected: Int {
        ruleReport.pulled + ruleReport.pushed + ruleReport.conflicts
    }
    
    var taskRowsAffected: Int {
        taskReport.pulled + taskReport.pushed + taskReport.conflicts
    }
    
    var totalRowsAffected: Int {
        eventRowsAffected + overrideRowsAffected + ruleRowsAffected + taskRowsAffected
    }
}

final class SyncCoordinator {
    private let db: DatabaseActor
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
        self.db = db
        self.supabase = supabase
        let syncApi = SupabaseSyncAPI(client: supabase)
        
        let center = ConflictResolutionCenter(
            db: db,
            resolvers: [
                TaskConflictResolver(api: syncApi),
                EventConflictResolver(api: syncApi),
                RecurrenceRuleConflictResolver(api: syncApi),
                EventOverrideConflictResolver(api: syncApi)
            ]
        )
        
        self.events = EventSyncEngine(db: db, api: syncApi, center: center)
        self.rules = RecurrenceRuleSyncEngine(db: db, api: syncApi, center: center)
        self.overrides = EventOverrideSyncEngine(db: db, api: syncApi, center: center)
        self.userTasks = UserTaskSyncEngine(db: db, api: syncApi, center: center)

        Task(priority: .utility) {
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

        let eventReport = try await eventRunner.syncNow()
        let ruleReport  = try await ruleRunner.syncNow()
        let overrideReport = try await overrideRunner.syncNow()
        let taskReport = try await taskRunner.syncNow()

        let summary = SyncSummary(
            eventReport: eventReport,
            ruleReport: ruleReport,
            overrideReport: overrideReport,
            taskReport: taskReport
        )

        // Reschedule reminders if:
        // 1. Data was pulled from server (could be reinstall/new device), OR
        // 2. First sync since app launch (detected via UserDefaults)
        let shouldRescheduleReminders = summary.totalRowsAffected > 0 || !hasScheduledRemindersThisSession()

        if shouldRescheduleReminders {
            log("Sync affected \(summary.totalRowsAffected) rows, rescheduling reminders...", level: .info, category: "Sync")
            await rescheduleRemindersAfterSync(db: db)
            markRemindersScheduledThisSession()
        }

        return summary
    }

    /// Reschedule all future reminders after sync
    /// Called when data is pulled from server (reinstall, new device, etc.)
    private func rescheduleRemindersAfterSync(db: DatabaseActor) async {
        log("Rescheduling reminders after sync", level: .info, category: "Sync")

        let now = Date()

        // Fetch all tasks and events with future due dates
        do {
            // Fetch tasks
            let allTasks = try await db.fetchAllUserTasks(userId: try await supabase.auth.session.user.id)
            let futureTasks = allTasks.filter {
                guard let dueDate = $0.dueDate else { return false }
                return dueDate > now && $0.reminderTriggers?.isEmpty == false
            }

            // Fetch events
            let allEvents = try await db.fetchOccurrences(userId: try await supabase.auth.session.user.id)
            let futureEvents = allEvents
                .map { EventOccurrence(occ: $0) }
                .filter {
                    $0.startDate > now && $0.reminderTriggers?.isEmpty == false
                }

            // Batch reschedule
            let taskScheduler = ReminderScheduler<UserTask>()
            let eventScheduler = ReminderScheduler<EventOccurrence>()
            
            // Clear ALL pending reminders first for clean slate
            // This is more efficient than iOS replacing each one individually
//            await clearAllReminders()
            await eventScheduler.clearAllReminders()

            try? await taskScheduler.scheduleReminders(for: futureTasks)
            try? await eventScheduler.scheduleReminders(for: futureEvents)

            log("Rescheduled \(futureTasks.count) task reminders and \(futureEvents.count) event reminders",
                level: .info, category: "Sync")
        } catch {
            log("Failed to reschedule reminders: \(error.localizedDescription)", level: .error, category: "Sync")
        }
    }

//    /// Remove all pending notifications for this app
//    /// Used before full reschedule to ensure clean slate
//    private func clearAllReminders() async {
//        let center = UNUserNotificationCenter.current()
//        let pending = await center.pendingNotificationRequests()
//
//        log("Clearing \(pending.count) pending notifications before reschedule", level: .debug, category: "Sync")
//
//        await center.removeAllPendingNotificationRequests()
//    }

    // MARK: - Reminder Scheduling Tracking

    private static let lastReminderScheduleKey = "sync.reminders.last.schedule.date"

    private func hasScheduledRemindersThisSession() -> Bool {
        // Check if last schedule was recent (within 12 hours)
        // This prevents rescheduling on every sync while still catching reinstalls
        guard let lastSchedule = UserDefaults.standard.object(forKey: Self.lastReminderScheduleKey) as? Date else {
            log("No previous reminder schedule found, will reschedule", level: .debug, category: "Sync")
            return false
        }

        let hoursSinceLastSchedule = Date().timeIntervalSince(lastSchedule) / 3600

        if hoursSinceLastSchedule < 12 {
            log("Reminders were scheduled \(Int(hoursSinceLastSchedule)) hours ago, skipping reschedule",
                level: .debug, category: "Sync")
            return true
        } else {
            log("Last schedule was \(Int(hoursSinceLastSchedule)) hours ago (>12h), will reschedule",
                level: .debug, category: "Sync")
            return false
        }
    }

    private func markRemindersScheduledThisSession() {
        UserDefaults.standard.set(Date(), forKey: Self.lastReminderScheduleKey)
    }
}
