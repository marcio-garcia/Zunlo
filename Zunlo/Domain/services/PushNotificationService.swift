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
        UNUserNotificationCenter.current().delegate = self
        
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

extension PushNotificationService: UNUserNotificationCenterDelegate {
    // to respond to incoming notifications while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle tapping notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("payload: \(userInfo)")
        completionHandler()
    }
}
