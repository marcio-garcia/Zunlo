//
//  TodayView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI
import GlowUI
import FlowNavigator
import AdStack

struct TodayView: View {
    @State private var viewID = UUID()
    
    var namespace: Namespace.ID
    @Binding var showChat: Bool
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var nav: AppNav
    @EnvironmentObject var upgradeFlowManager: UpgradeFlowManager
    @EnvironmentObject var upgradeReminderManager: UpgradeReminderManager
    @EnvironmentObject var policyProvider: SuggestionPolicyProvider
    @EnvironmentObject var store: ToolExecutionStore
    
    @AppStorage("firstLaunchTimestamp") private var firstLaunchTimestamp: Double = 0
    @AppStorage("sessionCount") private var sessionCount = 0
    @AppStorage("hasDismissedUpgradeReminder") private var dismissed = false
    private let minSessionsBeforeShowing = 5
    private let daysUntilBanner = 3
    
    @StateObject private var viewModel: TodayViewModel
    
    @State private var showRequestPush = false
    @State private var editableUserTask: UserTask?
    @State private var hasEarnedReward = false
    @State private var toast: Toast?
    @State private var aiContext: AIContext?
    @State private var factory: NavigationViewFactory?
    
    private let appState: AppState
    
    init(namespace: Namespace.ID,
         showChat: Binding<Bool>,
         appState: AppState
    ) {
        self.namespace = namespace
        self._showChat = showChat
        self.appState = appState
        _viewModel = StateObject(wrappedValue: TodayViewModel(appState: appState))
    }
    
    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            
            switch viewModel.state {
            case .empty, .loaded:
                NavigationStack(path: nav.pathBinding(for: viewID)) {
                    ZStack(alignment: .bottomTrailing) {
                        
                        ScrollView(.vertical) {
                            VStack(alignment: .leading, spacing: 24) {
                                TodayWeatherView(weather: viewModel.weather, greeting: viewModel.greeting)
                                
                                // Optionally reflect any ongoing runs:
                                //                                if let running = store.runs.values.first(where: { $0.isRunning }) {
                                //                                    ProgressView(running.status ?? "Working…", value: running.progress, total: 1)
                                //                                        .padding()
                                //                                }
                                
                                //                                AIWelcomeCard(
                                //                                    vm: AIWelcomeCardViewModel(
                                //                                        time: SystemTimeProvider(),
                                //                                        policyProvider: policyProvider,
                                //                                        tasksEngine: appState.taskSuggestionEngine!,
                                //                                        eventsEngine: appState.eventSuggestionEngine!,
                                //                                        aiToolRunner: DefaultAIToolRunner(
                                //                                            toolRepo: AIToolRepository(
                                //                                                eventRepo: appState.eventRepository!,
                                //                                                taskRepo: appState.userTaskRepository!,
                                //                                                eventEngine: appState.eventSuggestionEngine!),
                                //                                            calendar: .appDefault,
                                //                                            nav: nil),
                                //                                        weather: WeatherService.shared
                                //                                    )
                                //                                )
                                
                                if let ctx = aiContext {
                                    AIWelcomeCard(
                                        vm: AIWelcomeCardViewModel(
                                            context: ctx,
                                            aiToolRunner: DefaultAIToolRunner(
                                                userId: ctx.userId,
                                                toolRepo: AIToolRepository(
                                                    eventRepo: appState.eventRepository!,
                                                    taskRepo: appState.userTaskRepository!,
                                                    eventEngine: appState.eventSuggestionEngine!),
                                                calendar: .appDefault,
                                                nav: nil)
                                        )
                                    )
                                }
                                
                                if upgradeReminderManager.shouldShowReminder(isAnonymous: authManager.isAnonymous) {
                                    showBannerSection
                                }
                                eventsTodaySection
                                    .redacted(reason: viewModel.todayEvents.isEmpty ? .placeholder : [])
                                    .shimmer(active: viewModel.todayEvents.isEmpty)
                                
                                tasksTodaySection
//                                    .redacted(reason: viewModel.todayTasks.isEmpty ? .placeholder : [])
//                                    .shimmer(active: viewModel.todayTasks.isEmpty)
                            }
                            .padding(.top, 88)
                            .padding()
                        }
                        .refreshable {
                            Task {
                                try? await fetchInfo()
                            }
                        }
                        .background(
                            RemoteBackgroundImage(
                                lowResName: lowResName(for: viewModel.weather),
                                remoteName: remoteName(for: viewModel.weather),
                                fileStorage: RemoteStorageService(supabase: appState.supabaseClient!)
                            )
                            .ignoresSafeArea()
                        )
                        .sheet(item: nav.sheetBinding(for: viewID)) { route in
                            ViewRouter.sheetView(for: route, navigationManager: nav, factory: factory!)
                        }
                        .confirmationDialog(
                            "Edit Recurring Event",
                            isPresented: nav.isDialogPresented(for: viewID),
                            titleVisibility: .visible
                        ) {
                            if let route = nav.dialogRoute(for: viewID) {
                                ViewRouter.dialogView(
                                    for: route,
                                    navigationManager: nav,
                                    factory: factory!,
                                    onOptionSelected: { option in
                                        guard let editOption = EditEventDialogOption(rawValue: option) else {
                                            nav.dismissDialog(for: viewID)
                                            return
                                        }
                                        switch editOption {
                                        case .single:
                                            guard let editMode = viewModel.eventEditHandler.selectEditOnlyThisOccurrence() else { return }
                                            nav.showSheet(.editEvent(editMode), for: viewID)
                                        case .all:
                                            guard let editMode = viewModel.eventEditHandler.selectEditAllOccurrences() else { return }
                                            nav.showSheet(.editEvent(editMode), for: viewID)
                                        case .future:
                                            guard let editMode = viewModel.eventEditHandler.selectEditFutureOccurrences() else { return }
                                            nav.showSheet(.editEvent(editMode), for: viewID)
                                        case .cancel:
                                            nav.dismissDialog(for: viewID)
                                        }
                                    })
                            }
                        }
                        .presentToolOutcomes(toast: $toast, includeKind: { kind in
                            if case .aiTool = kind { return true }
                                                return false
                        }, onNavigate: { route in
                            switch route {
                            case let .taskDetail(id): /* nav.push(.taskDetail(id: id)) */
                                break
                            case let .eventDetail(id): /* nav.push(.eventDetail(id: id)) */
                                break
                            case let .url(url):        /* nav.open(url) */
                                break
                            }
                        })
                        
                        VStack(spacing: 0) {
                            ToolbarView(blurStyle: .systemUltraThinMaterial /*Theme.isDarkMode ? .dark : .light*/) {
                                Button(action: { nav.showSheet(.settings, for: viewID) }) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 22, weight: .regular))
                                }
                            } center: {
                                Text("Zunlo")
                                    .themedHeadline()
                            } trailing: {
                                HStack(alignment: .center, spacing: 16) {
                                    Button(action: { nav.showSheet(.addTask, for: viewID) }) {
                                        Image(systemName: "note.text.badge.plus")
                                            .font(.system(size: 22, weight: .regular))
                                    }
                                    .background(
                                        Color.clear
                                            .frame(width: 44, height: 44)
                                            .contentShape(Rectangle())
                                    )
                                    
                                    Button(action: { nav.showSheet(.addEvent, for: viewID) }) {
                                        Image(systemName: "calendar.badge.plus")
                                            .font(.system(size: 22, weight: .regular))
                                    }
                                    .background(
                                        Color.clear
                                            .frame(width: 44, height: 44)
                                            .contentShape(Rectangle())
                                    )
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, 44)
                        
                        Button(action: { showChat = true }) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    Circle()
                                        .fill(Color.accentColor)
                                        .matchedGeometryEffect(id: "chatMorph", in: namespace, isSource: !showChat)
                                )
                        }
                        .padding()
                        
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationTitle("")
                    .navigationDestination(for: StackRoute.self, destination: { route in
                        ViewRouter.navigationDestination(for: route, navigationManager: nav, factory: factory!)
                    })
                    .ignoresSafeArea()
                    .matchedGeometryEffect(id: "chatScreen", in: namespace, isSource: !showChat)
                    .toast($toast)
                }
            case .loading:
                VStack {
                    ProgressView("Loading...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .defaultBackground()
                
            case .error(let message):
                VStack {
                    Text(message)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .defaultBackground()
            }
        }
        .onAppear {
            sessionCount += 1
            if firstLaunchTimestamp == 0 {
                setFirstLaunchDate(Date())
            }
        }
        .task {
            factory = try? await getNavViewFactory()
            try? await fetchInfo()
            await appState.adManager?.loadInterstitial(for: .openCalendar)
            await appState.adManager?.loadRewarded(for: .chat)
        }
        .errorAlert(viewModel.errorHandler)
    }
    
    private var showBannerSection: some View {
        UpgradeReminderBanner(
            onUpgradeTap: {
                upgradeFlowManager.shouldShowUpgradeFlow = true
            },
            onDismissTap: {
                upgradeReminderManager.dismissReminder()
            }
        )
    }
    
    private var eventsTodaySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label {
                        Text("Events Today").themedBody()
                    } icon: {
                        Image(systemName: "calendar")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(Color.theme.text)
                    }
                    if viewModel.isSyncingDB {
                        ProgressView()
                    }
                    Spacer()
                    Button(action: {
                        nav.navigate(to: .eventCalendar)
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(Color.theme.text)
                    }
                    .background(
                        Color.clear
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.todayEvents) { event in
                        EventRow(occurrence: event, onTap: {
                            if event.isFakeOccForEmptyToday {
                                nav.showSheet(.addEvent, for: viewID)
                            } else if event.isRecurring {
                                nav.showDialog(.editRecurringEvent, for: viewID)
                            } else {
                                nav.showSheet(.editEvent(.editAll(event: event, recurrenceRule: nil)), for: viewID)
                            }
                            viewModel.onEventEditTap(event)
                        })
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .themedCard(blurBackground: true)
    }
    
    private var tasksTodaySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label {
                        Text("Tasks Today").themedBody()
                    } icon: {
                        Image(systemName: "note.text")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(Color.theme.text)
                    }
                    if viewModel.isSyncingDB {
                        ProgressView()
                    }
                    Spacer()
                    Button(action: {
                        nav.navigate(to: .taskInbox)
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(Color.theme.text)
                    }
                    .background(
                        Color.clear
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    )
                }
                
//                Text(hasEarnedReward ? "🎉 You earned 50 coins!" : "Watch an ad to earn coins")
//                Button("Watch Ad") {
//                    viewModel.showAd(type: .rewarded(.chat)) {
//                        
//                    } onRewardEarned: { amount, type in
//                        hasEarnedReward = true
//                    }
//                }
                
                if viewModel.todayTasks.isEmpty {
                    Text("No tasks for today.")
                        .themedBody()
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.todayTasks) { task in
                            TaskRow(task: task, chipType: .small) {
                                viewModel.toggleTaskCompletion(for: task)
                            } onTap: {
                                editableUserTask = task
                                nav.showSheet(.editTask(task), for: viewID)
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .themedCard(blurBackground: true)
    }
    
    func getFirstLaunchDate() -> Date {
        Date(timeIntervalSince1970: firstLaunchTimestamp)
    }
    
    func setFirstLaunchDate(_ date: Date) {
        firstLaunchTimestamp = date.timeIntervalSince1970
    }
    
    var shouldShowUpgradeReminder: Bool {
        let daysUntilBanner = 3
        let elapsed = Date().timeIntervalSince(getFirstLaunchDate())
        return authManager.isAnonymous &&
        elapsed > TimeInterval(60 * 60 * 24 * daysUntilBanner) &&
        !dismissed
    }
    
    func lowResName(for weather: WeatherInfo?) -> String {
        let name = backgroundImageName
        if name == "bg_default" {
            if Theme.isDarkMode {
                return "\(name)_low_dark"
            }
            return "\(name)_low_light"
        }
        return "\(name)_low"
    }
    
    func remoteName(for weather: WeatherInfo?) -> String? {
        let name = backgroundImageName
        return name == "bg_default" ? nil : "\(name).heic"
    }
    
    private var backgroundImageName: String {
        let hour = Calendar.appDefault.component(.hour, from: Date())
        let isDay = (6...17).contains(hour)
        
        guard let weather = viewModel.weather else { return "bg_default"}
        
        switch weather.condition {
        case .clear, .mostlyClear: return isDay ? "bg_clear_day" : "bg_clear_night"
        case .partlyCloudy, .mostlyCloudy: return isDay ? "bg_partly_cloudy_day" : "bg_partly_cloudy_night"
        case .cloudy, .windy: return isDay ? "bg_cloudy_day" : "bg_cloudy_night"
        case .rain: return isDay ? "bg_rain_day" : "bg_rain_night"
        case .snow: return isDay ? "bg_snow_day" : "bg_snow_night"
        case .foggy: return isDay ? "bg_fog_day" : "bg_fog_night"
        default: return "bg_default"
        }
    }
    
    private func getNavViewFactory() async throws -> NavigationViewFactory {
        guard try await authManager.isAuthorized(), let userId = authManager.userId else {
            return NavigationViewFactory()
        }
        let taskFactory = TaskViewFactory(
            viewID: viewID,
            nav: nav,
            userId: try await getUserId(),
            editableTaskProvider: { self.editableUserTask },
            onAddEditTaskViewDismiss: {
                Task { await viewModel.fetchData() }
            },
            onTaskInboxDismiss: {
                Task { await viewModel.fetchData() }
            }
        )
        let eventFactory = EventViewFactory(
            viewID: viewID,
            nav: nav,
            userId: userId,
            onAddEditEventDismiss: {
                Task { await viewModel.fetchData() }
            })
        let settingsFactory = SettingsViewFactory(authManager: appState.authManager!)
        let factory = NavigationViewFactory(
            task: taskFactory,
            event: eventFactory,
            settings: settingsFactory
        )
        return factory
    }
    
    private func getUserId() async throws -> UUID {
        guard try await authManager.isAuthorized(), let userId = authManager.userId else {
            return UUID()
        }
        return userId
    }
    
    private func fetchInfo() async throws {
        guard try await authManager.isAuthorized(), let userId = authManager.userId else {
            return
        }
        await viewModel.fetchData()
        await viewModel.fetchWeather()
        await viewModel.syncDB()
        aiContext = await AIContextBuilder().build(
            userId: userId,
            time: SystemTimeProvider(),
            policyProvider: policyProvider,
            tasks: appState.taskSuggestionEngine!,
            events: appState.eventSuggestionEngine!,
            weather: WeatherService.shared,
            on: Date()
        )
    }
}
