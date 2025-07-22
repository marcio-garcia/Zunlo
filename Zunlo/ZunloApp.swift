//
//  ZunloApp.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import SwiftUI
import SupabaseSDK
import RealmSwift
import Firebase

@main
struct ZunloApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var upgradeFlowManager = UpgradeFlowManager()
    @StateObject var upgradeReminderManager = UpgradeReminderManager()
    
    private let appState: AppState
    
    init() {
        setupRealm()
        
        let authManager = AuthManager()
        let locationService = LocationService()
        
        let supabaseConfig = SupabaseConfig(
            anonKey: EnvConfig.shared.apiKey,
            baseURL: URL(string: EnvConfig.shared.apiBaseUrl)!,
            functionsBaseURL: URL(string: EnvConfig.shared.apiFunctionsBaseUrl)
        )
        let supabase = SupabaseSDK(config: supabaseConfig)
        
        let firebase = FirebaseService()
        
        let pushService = PushNotificationService(
            authManager: authManager,
            pushTokenStore: SupabasePushTokensRemoteStore(supabase: supabase, authManager: authManager),
            firebaseService: firebase
        )
        
        let eventRepo = EventRepositoryFactory.make(
            supabase: supabase,
            authManager: authManager
        )
        
        let taskRepo = UserTaskRepository(
            localStore: RealmUserTaskLocalStore(),
            remoteStore: SupabaseUserTaskRemoteStore(supabase: supabase, authManager: authManager)
        )
        
        let chatRepo = DefaultChatRepository(store: RealmChatLocalStore(), userId: nil)
        
        let state = AppState(
            authManager: authManager,
            supabase: supabase,
            locationService: locationService,
            pushNotificationService: pushService,
            eventRepository: eventRepo,
            userTaskRepository: taskRepo,
            chatRepository: chatRepo
        )
        
        self.appState = state
        
        firebase.configure()
        pushService.start()
        appDelegate.pushNotificationService = pushService
    }

    var body: some Scene {
        WindowGroup {
            RootView(appState: appState)
                .environmentObject(appState.authManager)
                .environmentObject(appState.locationService)
                .environmentObject(upgradeFlowManager)
                .environmentObject(upgradeReminderManager)
                .onOpenURL { url in
                    handleAuthCallback(url: url)
                }
        }
    }
    
    private func handleAuthCallback(url: URL) {
        print("Received URL: \(url)")
        
        if url.scheme == "zunloapp" {
            Task {
                await processSupabaseCallback(url: url)
            }
        }
    }
    
    private func processSupabaseCallback(url: URL) async {
        NotificationCenter.default.post(name: .supabaseMagicLinkReceived, object: url)
        
        // Supabase should automatically handle the session
        // You can also manually process if needed
//        if let user = supabase.auth.currentUser {
//            print("User upgraded successfully: \(user.email ?? "No email")")
//            // Update your app state accordingly
//        }
    }
}

func setupRealm() {
    let config = Realm.Configuration(
        schemaVersion: 10, // <- increment this every time you change schema!
        migrationBlock: { migration, oldSchemaVersion in
            if oldSchemaVersion < 10 {
                // For new 'color' property on EventLocal/EventOverrideLocal,
                // Realm will auto-initialize it to the default value.
                // If you want to set a custom default, do it here:
//                migration.enumerateObjects(ofType: EventLocal.className()) { oldObject, newObject in
//                    newObject?["color"] = "#FFD966" // Default pastel yellow (or whatever you like)
//                }
//                migration.enumerateObjects(ofType: EventOverrideLocal.className()) { oldObject, newObject in
//                    newObject?["color"] = "#FFD966"
//                }
                migration.enumerateObjects(ofType: UserTaskLocal.className()) { oldObject, newObject in
                    if let obj = newObject?["priority"] as? String, obj == "low" {
                        newObject?["priority"] = 0
                    } else if let obj = newObject?["priority"] as? String, obj == "high" {
                        newObject?["priority"] = 2
                    } else {
                        newObject?["priority"] = 1
                    }
                    
                }
            }
        }
    )
    Realm.Configuration.defaultConfiguration = config
    // let _ = try! Realm() // Force Realm to initialize now
}
