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
        }
    }
}

func setupRealm() {
    let config = Realm.Configuration(
        schemaVersion: 7, // <- increment this every time you change schema!
        migrationBlock: { migration, oldSchemaVersion in
            if oldSchemaVersion < 2 {
                // For new 'color' property on EventLocal/EventOverrideLocal,
                // Realm will auto-initialize it to the default value.
                // If you want to set a custom default, do it here:
//                migration.enumerateObjects(ofType: EventLocal.className()) { oldObject, newObject in
//                    newObject?["color"] = "#FFD966" // Default pastel yellow (or whatever you like)
//                }
//                migration.enumerateObjects(ofType: EventOverrideLocal.className()) { oldObject, newObject in
//                    newObject?["color"] = "#FFD966"
//                }
            }
        }
    )
    Realm.Configuration.defaultConfiguration = config
    // let _ = try! Realm() // Force Realm to initialize now
}
