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
import SmartParseKit

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
    @StateObject private var toolStore = ToolExecutionStore()
    @State private var deepLinkHandler: DeepLinkHandler?
    
    private let appState: AppState
    
    init() {
        setupRealm()
        
//        let engine = IntentEngine.bundled() // IntentEngine(modelURL: Bundle.main.url(forResource: "ZunloIntents", withExtension: "mlmodelc"))
//        let label = engine.classify("create task to buy cat food tomorrow")
//        assert(label == .createTask || label == .createEvent || label == .updateReschedule) // whatever you expect
        
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
            auth: authManager,
            supabase: supabase,
            localDB: localDB
        )
        
        let taskRepo = UserTaskRepository(
            auth: authManager,
            localStore: RealmUserTaskLocalStore(db: localDB),
            remoteStore: SupabaseUserTaskRemoteStore(supabase: supabase, auth: authManager)
        )
        
        let chatRepo = DefaultChatRepository(store: RealmChatLocalStore(db: localDB))
        
        let eventSuggestionEngine = DefaultEventSuggestionEngine(
            auth: authManager,
            calendar: Calendar.appDefault,
            eventFetcher: EventFetcher(repo: eventRepo),
            policy: SuggestionPolicyProvider().policy
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
                .environmentObject(toolStore)
                .onAppear(perform: {
                    if deepLinkHandler == nil {
                        deepLinkHandler = DeepLinkHandler(appState: appState, nav: appNavigationManager)
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
        schemaVersion: 21, // <- increment this every time you change schema!
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
            if oldSchemaVersion < 14 {
                migration.enumerateObjects(ofType: EventLocal.className()) { _, newObj in
                    newObj?["version"] = nil
                }
                migration.enumerateObjects(ofType: RecurrenceRuleLocal.className()) { _, newObj in
                    newObj?["version"] = nil
                }
                migration.enumerateObjects(ofType: EventOverrideLocal.className()) { _, newObj in
                    newObj?["version"] = nil
                }
                migration.enumerateObjects(ofType: UserTaskLocal.className()) { _, newObj in
                    newObj?["version"] = nil
                }
                // Add SyncConflictLocal if new
            }
            if oldSchemaVersion < 15 {
                migration.enumerateObjects(ofType: ChatMessageLocal.className()) { oldObject, newObject in
                    newObject?["actions"] = []
                    newObject?["attachments"] = []
                }
            }
            if oldSchemaVersion < 16 {
                migration.enumerateObjects(ofType: ChatMessageLocal.className()) { oldObject, newObject in
                    newObject?["rawText"] = oldObject?["text"]
                    newObject?["formatRaw"] = "plain"
                }
            }
            if oldSchemaVersion < 17 {
                migration.enumerateObjects(ofType: UserTaskLocal.className()) { oldObject, newObject in
                    newObject?["userId"] = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
                }
            }
            if oldSchemaVersion < 19 {
//                migration.enumerateObjects(ofType: SyncCursor.className()) { oldObject, newObject in
//                    newObject?["lastTsRaw"] = nil
//                }
            }
            if oldSchemaVersion < 20 {
                migration.enumerateObjects(ofType: EventLocal.className()) { oldObject, newObject in
                    newObject?["userId"] = UUID(uuidString: "2d2c47af-3923-4524-8e85-be91371483f5")!
                }
            }
            if oldSchemaVersion < 21 {
                migration.enumerateObjects(ofType: SyncConflictLocal.className()) { oldObject, newObject in
                    newObject?["statusRaw"] = ConflictStatus.pending.rawValue
                    newObject?["attempts"] = 0
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
