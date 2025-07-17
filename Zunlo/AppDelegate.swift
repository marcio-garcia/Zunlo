//
//  AppDelegate.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/14/25.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    weak var pushNotificationService: PushNotificationService?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("******** APNS didRegisterForRemoteNotifications")
        pushNotificationService?.registerAPNsToken(deviceToken)
    }
}
