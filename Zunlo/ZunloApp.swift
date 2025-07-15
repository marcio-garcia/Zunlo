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
    
    private let authManager = AuthManager()
    private let locationManager = LocationManager()
    private let pushNotificationService: PushNotificationService
    private let supabaseSDK: SupabaseSDK
    private let eventRepository: EventRepository
    private let userTaskRepository: UserTaskRepository
    private let chatRepository: ChatRepository
    private let firebaseService: FirebaseService
    
    private let appState: AppState
    
    init() {
        setupRealm()
        configureFirebase()
        
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
            locationManager: locationManager,
            pushNotificationService: pushService,
            eventRepository: eventRepo,
            userTaskRepository: taskRepo,
            chatRepository: chatRepo
        )
        
        self.supabaseSDK = supabase
        self.firebaseService = firebase
        self.pushNotificationService = pushService
        self.eventRepository = eventRepo
        self.userTaskRepository = taskRepo
        self.chatRepository = chatRepo
        self.appState = state
        
        pushService.start()
        appDelegate.pushNotificationService = pushService
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
