//
//  AppDelegate.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/14/25.
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    weak var pushNotificationService: PushNotificationService?
    weak var notificationActionHandler: NotificationActionHandler?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Register notification categories with actions
        NotificationActionHandler.registerNotificationCategories()

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("******** APNS didRegisterForRemoteNotifications")
        pushNotificationService?.registerAPNsToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("******** APNS failed to register: \(error.localizedDescription)")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Handle notification when app is in foreground
    /// Works for BOTH local reminders and remote push notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        // Check if it's a remote notification
        if let aps = userInfo["aps"] as? [String: Any] {
            print("📥 Received remote push notification in foreground")
            print("   APS: \(aps)")
        } else {
            print("🔔 Received local notification in foreground")
        }

        // Show notification even when app is in foreground
        // This works for both local and remote notifications
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle user's response to notification action
    /// Works for BOTH local reminders and remote push notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Log notification source
        if userInfo["aps"] != nil {
            print("📥 User responded to remote push notification action")
        } else {
            print("🔔 User responded to local notification action")
        }

        // Delegate to NotificationActionHandler
        // Handler works the same for both local and remote notifications
        notificationActionHandler?.handleNotificationAction(
            response: response,
            completionHandler: completionHandler
        )
    }
}
