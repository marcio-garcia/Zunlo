//
//  ZunloApp.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import SwiftUI
import SwiftData
import SupabaseSDK
import RealmSwift
import FirebaseMessaging

@main
struct ZunloApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    private let authManager = AuthManager()
    private let locationManager = LocationManager()
    private let supabaseSDK: SupabaseSDK
    private let eventRepository: EventRepository
    private let userTaskRepository: UserTaskRepository
    private let chatRepository: ChatRepository
    
    private let appState: AppState
    init() {
        setupRealm()
        
        let supabaseConfig = SupabaseConfig(anonKey: EnvConfig.shared.apiKey,
                                            baseURL: URL(string: EnvConfig.shared.apiBaseUrl)!,
                                            functionsBaseURL: URL(string: EnvConfig.shared.apiFunctionsBaseUrl))
        supabaseSDK = SupabaseSDK(config: supabaseConfig)
        eventRepository = EventRepositoryFactory.make(supabase: supabaseSDK,
                                                      authManager: authManager)
        
        userTaskRepository = UserTaskRepository(localStore: RealmUserTaskLocalStore(),
                                                remoteStore: SupabaseUserTaskRemoteStore(supabase: supabaseSDK,
                                                                                         authManager: authManager))
        
        chatRepository = DefaultChatRepository(store: RealmChatLocalStore(), userId: nil)
        
        appState = AppState(authManager: authManager,
                            supabase: supabaseSDK,
                            locationManager: locationManager,
                            eventRepository: eventRepository,
                            userTaskRepository: userTaskRepository,
                            chatRepository: chatRepository)
        
        Messaging.messaging().token { token, error in
            if let token = token {
                print("FCM token again: \(token)")
                // Send this to your backend
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(appState: appState)
                .environmentObject(appState.authManager)
                .environmentObject(appState.locationManager)
        }
    }
}

func setupRealm() {
    let config = Realm.Configuration(
        schemaVersion: 5, // <- increment this every time you change schema!
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
