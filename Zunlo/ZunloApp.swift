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
import FlowNavigator
import AdStack
import Supabase

typealias AppNav = AppNavigationManager<SheetRoute, FullScreenRoute, DialogRoute, StackRoute>

/// If you're tracking in-app purchases, you must initialize your transaction observer in application:didFinishLaunchingWithOptions: before initializing Firebase,
/// or your observer may not receive all purchase notifications. See Apple's In-App Purchase Best Practices for more information.
/// https://developer.apple.com/documentation/storekit/in-app-purchase
@main
struct ZunloApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var upgradeFlowManager = UpgradeFlowManager()
    @StateObject var upgradeReminderManager = UpgradeReminderManager()
    @StateObject var appSettings = AppSettings()
    @StateObject var appNavigationManager = AppNav()
    @StateObject private var policyProvider = SuggestionPolicyProvider()
    @State private var deepLinkHandler: DeepLinkHandler?
    
    private let appState: AppState
    
    init() {
        setupRealm()
        
        let supabaseClient = SupabaseClient(
            supabaseURL: URL(string: EnvConfig.shared.apiBaseUrl)!,
            supabaseKey: EnvConfig.shared.apiKey
        )
        
        let authManager = AuthManager(authService: AuthService(supabase: supabaseClient))
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
            pushTokenStore: SupabasePushTokensRemoteStore(supabase: supabase, auth: authManager),
            firebaseService: firebase
        )
        
        AdEnvironment.configure(provider: EnvConfig.shared)
        let adManager = AdMobManager()
        
        let localDB = DatabaseActor()
        
        let eventRepo = EventRepositoryFactory.make(
            supabase: supabase,
            authManager: authManager,
            localDB: localDB
        )
        
        let taskRepo = UserTaskRepository(
            localStore: RealmUserTaskLocalStore(db: localDB),
            remoteStore: SupabaseUserTaskRemoteStore(supabase: supabase, auth: authManager)
        )
        
        let chatRepo = DefaultChatRepository(store: RealmChatLocalStore(db: localDB))
        
        let eventSuggestionEngine = DefaultEventSuggestionEngine(
            calendar: Calendar.appDefault,
            eventFetcher: EventFetcher(repo: eventRepo)
        )
        
        let taskSuggestionEngine = DefaultTaskSuggestionEngine(
            calendar: Calendar.appDefault,
            taskFetcher: UserTaskFetcher(repo: taskRepo)
        )
        
//        let state = AppState(
//            authManager: authManager,
//            supabase: supabase,
//            locationService: locationService,
//            pushNotificationService: pushService,
//            adManager: adManager,
//            eventRepository: eventRepo,
//            userTaskRepository: taskRepo,
//            chatRepository: chatRepo
//        )
        
        self.appState = AppState.shared
        
        self.appState.authManager = authManager
        self.appState.localDB = localDB
        self.appState.supabase = supabase
        self.appState.locationService = locationService
        self.appState.pushNotificationService = pushService
        self.appState.adManager = adManager
        self.appState.eventRepository = eventRepo
        self.appState.userTaskRepository = taskRepo
        self.appState.chatRepository = chatRepo
        self.appState.eventSuggestionEngine = eventSuggestionEngine
        self.appState.taskSuggestionEngine = taskSuggestionEngine
        self.appState.supabaseClient = supabaseClient
        
        firebase.configure()
        pushService.start()
        appDelegate.pushNotificationService = pushService
    }

    var body: some Scene {
        WindowGroup {
            RootView(appState: appState)
                .environmentObject(appNavigationManager)
                .environmentObject(appSettings)
                .environmentObject(appState.authManager!)
                .environmentObject(appState.locationService!)
                .environmentObject(upgradeFlowManager)
                .environmentObject(upgradeReminderManager)
                .environmentObject(policyProvider)
                .onAppear(perform: {
                    if deepLinkHandler == nil {
                        deepLinkHandler = DeepLinkHandler(navigationManager: appNavigationManager)
                    }
                })
                .onOpenURL { url in
                    if let deepLink = DeepLinkParser.parse(url: url) {
                        deepLinkHandler?.handleDeepLink(deepLink)
                    }
                }
        }
    }
}

func setupRealm() {
    let config = Realm.Configuration(
        schemaVersion: 13, // <- increment this every time you change schema!
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
}

extension UIApplication {
    var rootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
    }
}
