//
//  AppDelegate.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/14/25.
//

import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

func requestNotificationPermissions() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
        if granted {
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } else {
            print("User denied notifications: \(error?.localizedDescription ?? "No error")")
        }
    }
}

func configureFirebase() {
    var filePath: String?
    switch EnvConfig.shared.current {
    case .dev:
        filePath = Bundle.main.path(forResource: "GoogleService-Info-dev", ofType: "plist")
    case .prod:
        filePath = Bundle.main.path(forResource: "GoogleService-Info-prod", ofType: "plist")
    case .staging:
        filePath = Bundle.main.path(forResource: "GoogleService-Info-dev", ofType: "plist")
    }

    guard let fileopts = FirebaseOptions(contentsOfFile: filePath!) else {
        fatalError("Couldn't load Firebase config file")
    }
    FirebaseApp.configure(options: fileopts)
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureFirebase()
        
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        requestNotificationPermissions()
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // Optional: to respond to incoming FCM messages while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    // Optional: Handle tapping notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap here
        let userInfo = response.notification.request.content.userInfo

        // 🔍 1. Log or inspect payload
        print("🔔 Push tapped - payload: \(userInfo)")

        // 🧠 2. Handle deep link or payload content
        if let screen = userInfo["screen"] as? String {
            // Navigate based on payload, e.g., open a specific screen
//            navigateToScreen(named: screen)
        }
        completionHandler()
    }

    // Optional: receive FCM token update
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM token: \(fcmToken ?? "")")
        // Optionally, send token to your server
    }
}
