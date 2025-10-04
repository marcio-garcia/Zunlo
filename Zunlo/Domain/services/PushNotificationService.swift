//
//  PushNotificationService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/15/25.
//

import UIKit
import UserNotifications

final class PushNotificationService: NSObject {
    
    var authManager: AuthManager
    var pushTokenStore: PushTokensRemoteStore
    var firebaseService: FirebaseService

    let grantedUserDefultKey = "PushPermissionsGranted"
    let deniedUserDefultKey = "PushPermissionsDenied"
    
    init(authManager: AuthManager,
         pushTokenStore: PushTokensRemoteStore,
         firebaseService: FirebaseService) {
        self.authManager = authManager
        self.pushTokenStore = pushTokenStore
        self.firebaseService = firebaseService
    }

    var pushPermissionsGranted: Bool {
        get {
            UserDefaults.standard.object(forKey: self.grantedUserDefultKey) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: self.grantedUserDefultKey)
        }
    }
    
    var pushPermissionsDenied: Bool {
        get {
            UserDefaults.standard.object(forKey: self.deniedUserDefultKey) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: self.deniedUserDefultKey)
        }
    }
    
    func start() {
        firebaseService.onDidReceiveRegistrationToken = { [weak self] token in
            Task {
                guard let self else { return }
                print("onDidReceiveRegistrationToken - FCM token: \(token)")
                try await self.registerCurrentToken(token)
            }
        }
        
//        firebaseService.observeTokenRefresh { [weak self] token in
//            Task {
//                guard let self, let token else { return }
//                print("observeTokenRefresh - FCM token: \(token)")
//                try? await self.registerCurrentToken(token)
//            }
//        }
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
//            Task {
//                do {
//                    let token = try await self.firebaseService.getFCMToken()
//                    print("observeTokenRefresh - FCM token: \(token)")
//                } catch {
//                    print("Failed to get FCM token:", error)
//                }
//            }
//        }
    }
    
    func requestNotificationPermissions(completion: ((Bool) -> Void)?) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("User denied notifications: \(error?.localizedDescription ?? "No error")")
                self.pushPermissionsGranted = false
                self.pushPermissionsDenied = true
            }
            completion?(granted)
        }
    }
    
    func registerAPNsToken(_ deviceToken: Data) {
        firebaseService.setAPNsToken(deviceToken)
        self.pushPermissionsGranted = true
        self.pushPermissionsDenied = false
    }

    func getToken() async throws -> String {
        return try await firebaseService.getFCMToken()
    }

    private func registerCurrentToken(_ token: String) async throws {
        guard let accessToken = await self.getAccessToken(),
              let userId = await self.getUserId() else {
            print("Missing token or user credentials.")
            return
        }

        let payload = PushTokenRemote(
            id: nil,
            user_id: userId.uuidString,
            token: token,
            platform: "iOS",
            app_version: EnvConfig.shared.appVersion
        )
        
        try await saveToken(payload: payload, accessToken: accessToken)
    }
    
    private func saveToken(payload: PushTokenRemote, accessToken: String) async throws {
        do {
            let pushToken = try await pushTokenStore.save(payload)
            for token in pushToken {
                print("Push token registered/updated successfully. Token: \(token.token)")
            }
        } catch {
            print("Push token registration failed with response: \(error.localizedDescription)")
            return
        }
    }
    
    @MainActor
    private func getAccessToken() -> String? {
        return authManager.authToken?.accessToken
    }

    @MainActor
    private func getUserId() -> UUID? {
        return authManager.user?.id
    }
}
//
//Architecture Overview
//
//┌────────────────────────────────────────────────────────────────┐
//│                        iOS App Launch                           │
//└────────────────────────────────────────────────────────────────┘
//                              │
//                              ▼
//┌────────────────────────────────────────────────────────────────┐
//│                     AppDelegate.swift                           │
//│                                                                  │
//│  • Registers notification categories (TASK_REMINDER, EVENT)    │
//│  • Sets UNUserNotificationCenterDelegate                       │
//│  • Initializes PushNotificationService                         │
//│  • Initializes NotificationActionHandler                       │
//└────────────────────────────────────────────────────────────────┘
//                              │
//                 ┌────────────┴────────────┐
//                 ▼                         ▼
//┌──────────────────────────┐  ┌──────────────────────────┐
//│  Local Notifications      │  │ Remote Notifications      │
//│  (ReminderScheduler)     │  │ (PushNotificationService)│
//│                          │  │                          │
//│ • Scheduled reminders    │  │ • Server-triggered push  │
//│ • Uses TASK_REMINDER     │  │ • Uses TASK_REMINDER     │
//│ • Uses EVENT_REMINDER    │  │ • Uses EVENT_REMINDER    │
//└──────────────────────────┘  └──────────────────────────┘
//                 │                         │
//                 └────────────┬────────────┘
//                              ▼
//          ┌─────────────────────────────────────┐
//          │   Same Categories & Actions          │
//          │                                      │
//          │   TASK_REMINDER:                    │
//          │   • ✓ Mark Complete                 │
//          │   • ⏰ Snooze 1 hour                │
//          │                                      │
//          │   EVENT_REMINDER:                   │
//          │   • 📅 View Details                 │
//          └─────────────────────────────────────┘
//                              │
//                              ▼
//          ┌─────────────────────────────────────┐
//          │  NotificationActionHandler          │
//          │                                      │
//          │  Handles actions from BOTH:         │
//          │  • Local reminders                  │
//          │  • Remote push                      │
//          └─────────────────────────────────────┘
//
//---
//How Both Systems Work Together
//
//1. Shared Categories
//
//Both local and remote notifications use the same category identifiers:
//
//// Registered once, used by both systems
//enum NotificationCategory: String {
//    case taskReminder = "TASK_REMINDER"
//    case eventReminder = "EVENT_REMINDER"
//}
//
//Local notification:
//content.categoryIdentifier = NotificationCategory.taskReminder.rawValue
//
//Remote notification (from server):
//{
//  "aps": {
//    "category": "TASK_REMINDER"  // ← Same identifier!
//  }
//}
//
//---
//2. Unified Action Handling
//
//The NotificationActionHandler processes actions regardless of source:
//
//func userNotificationCenter(
//    _ center: UNUserNotificationCenter,
//    didReceive response: UNNotificationResponse,
//    withCompletionHandler completionHandler: @escaping () -> Void
//) {
//    // Works for BOTH local and remote
//    notificationActionHandler?.handleNotificationAction(
//        response: response,
//        completionHandler: completionHandler
//    )
//}
//
//---
//Real-World Scenarios
//
//Scenario 1: Local Reminder
//
//User creates task "Buy milk" with reminder at 3pm
//    ↓
//ReminderScheduler schedules local notification
//    ↓
//3pm - Local notification fires
//    ↓
//User sees: [✓ Mark Complete] [⏰ Snooze]
//    ↓
//User taps "✓ Mark Complete"
//    ↓
//NotificationActionHandler → marks task complete
//    ↓
//Feedback: "✓ Task Completed - Buy milk"
//
//---
//Scenario 2: Remote Push Notification
//
//Server detects task "Submit report" is due soon
//    ↓
//Server sends FCM push with category: "TASK_REMINDER"
//    ↓
//PushNotificationService receives notification
//    ↓
//User sees: [✓ Mark Complete] [⏰ Snooze]  ← Same actions!
//    ↓
//User taps "⏰ Snooze"
//    ↓
//NotificationActionHandler → snoozes task (+1 hour)
//    ↓
//Feedback: "⏰ Task Snoozed - Reminder at 4:00 PM"
//
//---
//Scenario 3: Mixed Notifications
//
//User has:
//- Local reminder for "Team Meeting" at 2pm (scheduled on device)
//- Remote push for "Call client" (triggered by server)
//
//Both show up with same actions:
//┌─────────────────────────────────┐
//│ 📅 Team Meeting (local)         │
//│ 2:00 PM - 3:00 PM               │
//│ [📅 View Details]               │
//└─────────────────────────────────┘
//
//┌─────────────────────────────────┐
//│ 📋 Call client (remote)         │
//│ Due at 2:30 PM                  │
//│ [✓ Complete] [⏰ Snooze]        │
//└─────────────────────────────────┘
//
