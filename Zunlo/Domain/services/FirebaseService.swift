//
//  FirebaseService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/15/25.
//

import FirebaseCore
import FirebaseMessaging

final class FirebaseService: NSObject {

    var onDidReceiveRegistrationToken: ((_ token: String) -> Void)?
    
    func configure() {
        guard FirebaseApp.app() == nil else { return }

        var filePath: String?
        switch EnvConfig.shared.current {
        case .dev:
            filePath = Bundle.main.path(forResource: "GoogleService-Info-dev", ofType: "plist")
        case .prod:
            filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
        case .staging:
            filePath = Bundle.main.path(forResource: "GoogleService-Info-stg", ofType: "plist")
        }

        guard let filePath else {
            print("Firebase config missing: no plist for environment \(EnvConfig.shared.current).")
            return
        }

        guard let fileopts = FirebaseOptions(contentsOfFile: filePath) else {
            print("Firebase config missing: couldn't load plist at \(filePath).")
            return
        }
        print("***** Will configure Firebase")
        FirebaseApp.configure(options: fileopts)
        Messaging.messaging().delegate = self
    }

    func setAPNsToken(_ token: Data) {
        Messaging.messaging().apnsToken = token
    }

    func getFCMToken() async throws -> String {
        return try await Messaging.messaging().token()
    }

//    func observeTokenRefresh(_ handler: @escaping (String?) -> Void) {
//        NotificationCenter.default.addObserver(
//            forName: .MessagingRegistrationTokenRefreshed,
//            object: nil,
//            queue: .main
//        ) { _ in
//            Task { [weak self] in
//                guard let self else {
//                    handler(nil)
//                    return
//                }
//                let token = try await self.getFCMToken()
//                handler(token)
//            }
//        }
//    }
}

extension FirebaseService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            onDidReceiveRegistrationToken?(token)
        }
    }
}
