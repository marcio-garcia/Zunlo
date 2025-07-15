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
    
    init(authManager: AuthManager,
         pushTokenStore: PushTokensRemoteStore,
         firebaseService: FirebaseService) {
        self.authManager = authManager
        self.pushTokenStore = pushTokenStore
        self.firebaseService = firebaseService
    }

    func start() {
        UNUserNotificationCenter.current().delegate = self
        
        firebaseService.onDidReceiveRegistrationToken = { [weak self] token in
            Task {
                guard let self else { return }
                try await self.registerCurrentToken(token)
            }
        }
        
        firebaseService.observeTokenRefresh { [weak self] token in
            Task {
                guard let self, let token else { return }
                try? await self.registerCurrentToken(token)
            }
        }
    }
    
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
    
    func registerAPNsToken(_ deviceToken: Data) {
        firebaseService.setAPNsToken(deviceToken)
        UserDefaults.standard.set(false, forKey: "RequestPushPermissions")
    }

    func getToken() async throws -> String {
        return try await firebaseService.getFCMToken()
    }

    private func registerCurrentToken(_ token: String) async throws {
        guard let accessToken = self.getAccessToken(),
              let userId = self.getUserId() else {
            print("Missing token or user credentials.")
            return
        }

        let payload = PushTokenRemote(
            id: nil,
            user_id: userId,
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
    
    private func getAccessToken() -> String? {
        return authManager.accessToken
    }

    private func getUserId() -> String? {
        return authManager.auth?.user.id
    }
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
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
        print("payload: \(userInfo)")
        completionHandler()
    }
}
