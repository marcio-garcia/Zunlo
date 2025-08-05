//
//  TodayView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI
import FlowNavigator
import AdStack

struct TodayView: View {
    var namespace: Namespace.ID
    @Binding var showChat: Bool
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var nav: AppNavigationManager
    @EnvironmentObject var upgradeFlowManager: UpgradeFlowManager
    @EnvironmentObject var upgradeReminderManager: UpgradeReminderManager
    
    @AppStorage("firstLaunchTimestamp") private var firstLaunchTimestamp: Double = 0
    @AppStorage("sessionCount") private var sessionCount = 0
    @AppStorage("hasDismissedUpgradeReminder") private var dismissed = false
    private let minSessionsBeforeShowing = 5
    private let daysUntilBanner = 3
    
    @StateObject private var viewModel: TodayViewModel
    
    @State private var showRequestPush = false
    @State private var editableUserTask: UserTask?
    @State private var hasEarnedReward = false
    @State private var viewWidth: CGFloat = UIScreen.main.bounds.width
    
    private let appState: AppState
    
    init(namespace: Namespace.ID,
         showChat: Binding<Bool>,
         appState: AppState
    ) {
        self.namespace = namespace
        self._showChat = showChat
        self.appState = appState
        _viewModel = StateObject(wrappedValue: TodayViewModel(
            taskRepository: appState.userTaskRepository,
            eventRepository: appState.eventRepository,
            locationService: appState.locationService)
        )
    }
    
    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            
            switch viewModel.state {
            case .empty, .loaded:
                GeometryReader { geo in
                    NavigationStack(path: $nav.path) {
                        ZStack(alignment: .bottomTrailing) {
                            
                            ScrollView(.vertical) {
                                VStack(alignment: .leading, spacing: 24) {
                                    if let weather = viewModel.weather {
                                        TodayWeatherView(weather: weather, greeting: viewModel.greeting)
                                    }
                                    
                                    VStack(spacing: 0) {
                                        Spacer()
                                        BannerAdView(
                                            adUnitID: BannerPlacement.home.adUnitID,
                                            size: .adaptive,
                                            containerWidth: geo.size.width - 32,
                                            onEvent: { event in
                                                switch event {
                                                case .didReceiveAd:
                                                    print("✅ Ad received")
                                                case .didFailToReceiveAd(let error):
                                                    print("❌ Failed to load ad: \(error)")
                                                case .didClick:
                                                    print("👆 Ad clicked")
                                                default:
                                                    break
                                                }
                                            }
                                        )
                                        .frame(height: 50)
                                        .padding(.horizontal, 16)
                                    }
                                    .onChange(of: geo.size.width) { _, newWidth in viewWidth = newWidth }
                                    
                                    if upgradeReminderManager.shouldShowReminder(isAnonymous: authManager.isAnonymous) {
                                        showBannerSection
                                    }
                                    eventsTodaySection
                                    tasksTodaySection
                                }
                                .padding(.top, 44)
                                .padding()
                            }
                            .refreshable {
                                Task {
                                    await fetchInfo()
                                }
                            }
                            .background(
                                RemoteBackgroundImage(
                                    lowResName: lowResName(for: viewModel.weather),
                                    remoteName: remoteName(for: viewModel.weather)
                                )
                                .ignoresSafeArea()
                            )
                            .sheet(item: $nav.sheet, content: { route in
                                ViewRouter.sheetView(for: route, navigationManager: nav, builders: ViewBuilders(
                                    buildSettingsView: {
                                        AnyView(SettingsView(authManager: appState.authManager)
                                            .environmentObject(upgradeFlowManager))
                                    },
                                    buildAddTaskView: {
                                        AnyView(AddEditTaskView(viewModel: AddEditTaskViewModel(mode: .add, repository: appState.userTaskRepository)))
                                    },
                                    buildEditTaskView: { id in
                                        guard let editableUserTask, editableUserTask.id == id else {
                                            return AnyView(FallbackView(message: "Could not display edit task screen", nav: nav))
                                        }
                                        return AnyView(AddEditTaskView(viewModel: AddEditTaskViewModel(mode: .edit(editableUserTask), repository: appState.userTaskRepository)))
                                    },
                                    buildAddEventView: {
                                        AnyView(AddEditEventView(viewModel: AddEditEventViewModel(mode: .add, repository: appState.eventRepository)))
                                    },
                                    buildEditEventView: { id in
                                        guard let editMode = viewModel.eventEditHandler.editMode else {
                                            return AnyView(FallbackView(message: "Could not display edit event screen", nav: nav))
                                        }
                                        return AnyView(AddEditEventView(
                                            viewModel: AddEditEventViewModel(
                                                mode: editMode,
                                                repository: appState.eventRepository
                                            )
                                        ))
                                    }
                                ))
                            })
                            .fullScreenCover(item: $nav.fullScreen, content: { route in
                                ViewRouter.fullScreenView(for: route, navigationManager: nav, builders: ViewBuilders(
                                    buildTaskInboxView: {
                                        AnyView(TaskInboxView(repository: appState.userTaskRepository))
                                    },
                                    buildEventCalendarView: {
                                        AnyView(
                                            CalendarScheduleContainer(
                                                viewModel: CalendarScheduleViewModel(
                                                    repository: appState.eventRepository,
                                                    locationService: appState.locationService
                                                )
                                            )
                                            .ignoresSafeArea()
                                        )
                                    }
                                ))
                            })
                            .confirmationDialog("Edit Recurring Event", isPresented: Binding<Bool>(
                                get: { nav.dialog != nil },
                                set: { if !$0 { nav.dismissDialog() } }
                            ), titleVisibility: .visible) {
                                if let dialog = nav.dialog {
                                    ViewRouter.dialogButtons(for: dialog, navigationManager: nav, builders: ViewBuilders(
                                        buildEditRecurringView: {
                                            AnyView(Group {
                                                Button("Edit only this occurrence") {
                                                    viewModel.eventEditHandler.selectEditOnlyThisOccurrence()
                                                    nav.showSheet(.editEvent(UUID()))
                                                }
                                                Button("Edit all occurrences") {
                                                    viewModel.eventEditHandler.selectEditAllOccurrences()
                                                    nav.showSheet(.editEvent(UUID()))
                                                }
                                                Button("Cancel", role: .cancel) {
                                                    nav.dialog = nil
                                                }
                                            })
                                        }
                                    ))
                                }
                            }
                            
                            Button(action: { showChat = true }) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(
                                        Circle()
                                            .fill(Color.accentColor)
                                            .matchedGeometryEffect(id: "chatMorph", in: namespace)
                                    )
                            }
                            .padding()
                            
                            VStack(spacing: 0) {
                                ToolbarView(blurStyle: Theme.isDarkMode ? .dark : .light) {
                                    Button(action: { nav.showSheet(.settings) }) {
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.system(size: 22, weight: .regular))
                                    }
                                } center: {
                                    Text("Zunlo")
                                        .themedHeadline()
                                } trailing: {
                                    HStack(alignment: .center, spacing: 16) {
                                        Button(action: { nav.showSheet(.addTask) }) {
                                            Image(systemName: "note.text.badge.plus")
                                                .font(.system(size: 22, weight: .regular))
                                        }
                                        .background(
                                            Color.clear
                                                .frame(width: 44, height: 44)
                                                .contentShape(Rectangle())
                                        )
                                        
                                        Button(action: { nav.showSheet(.addEvent) }) {
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
                            
                        }
                        //                    .navigationTitle("")
                        //                    .navigationDestination(for: StackRoute.self, destination: { route in
                        //                        ViewRouter.navigationDestination(for: route, navigationManager: nav, builders: ViewBuilders(
                        //                            buildTaskInboxView: {
                        //                                AnyView(TaskInboxView(repository: appState.userTaskRepository))
                        //                            },
                        //                            buildEventCalendarView: {
                        //                                AnyView(CalendarScheduleContainer(
                        //                                    viewModel: CalendarScheduleViewModel(
                        //                                        repository: appState.eventRepository,
                        //                                        locationService: appState.locationService
                        //                                    )
                        //                                )
                        //                                    .navigationTitle("Title")
                        //                                    .ignoresSafeArea()
                        //                                )
                        //                            }
                        //                        ))
                        //                    })
                    }
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
            await fetchInfo()
            await appState.adManager.loadInterstitial(for: .openCalendar)
            await appState.adManager.loadRewarded(for: .chat)
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
                    Spacer()
                    Button(action: {
                        if let rootVC = UIApplication.shared.rootViewController {
                            appState.adManager.showAd(
                                .interstitial(.openCalendar),
                                from: rootVC) { event in
                                    switch event {
                                    case .didDismiss:
                                        nav.showFullScreen(.eventCalendar)
                                    case .didFailToPresent(let error):
                                        print("❌ Failed to present: \(error.localizedDescription)")
                                    case .didRecordImpression:
                                        print("📺 Interstitial ad presented")
                                    case .didClick:
                                        print("🖱️ Interstitial ad clicked")
                                    }
                                }
                        }
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
                
                if viewModel.todaysEvents.isEmpty {
                    Text("No events for today.")
                        .themedBody()
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.todaysEvents) { event in
                            EventRow(occurrence: event, onTap: {
                                if event.isRecurring {
                                    nav.showDialog(.editRecurringEvent)
                                } else {
                                    nav.showSheet(.editEvent(event.id))
                                }
                                viewModel.onEventEditTap(event)
                            })
                        }
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
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(Color.theme.text)
                    }
                    Spacer()
                    Button(action: { nav.showFullScreen(.taskInbox) }) {
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
                
                Text(hasEarnedReward ? "🎉 You earned 50 coins!" : "Watch an ad to earn coins")
                Button("Watch Ad") {
                    if let rootVC = UIApplication.shared.rootViewController {
                        appState.adManager.showAd(
                            .rewarded(.chat),
                            from: rootVC) { event in
                                switch event {
                                case .didDismiss:
                                    print("🏁 Reward flow complete")
                                case .didClick:
                                    print("🖱️ Rewarded ad clicked")
                                case .didFailToPresent(let error):
                                    print("❌ Failed to present: \(error.localizedDescription)")
                                case .didRecordImpression:
                                    print("📺 Rewarded ad presented")
                                }
                            } onRewardEarned: { amount, type in
                                hasEarnedReward = true
                            }
                    }
                }
                
                if viewModel.todaysTasks.isEmpty {
                    Text("No tasks for today.")
                        .themedBody()
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.todaysTasks) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskCompletion(for: task)
                            } onTap: {
                                guard let id = task.id else { return }
                                editableUserTask = task
                                nav.showSheet(.editTask(id))
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
        return "\(name)_low"
    }
    
    func remoteName(for weather: WeatherInfo?) -> String? {
        let name = backgroundImageName
        return name == "bg_default" ? nil : "\(name).heic"
    }
    
    private var backgroundImageName: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let isDay = (6...17).contains(hour)
        
        guard let weather = viewModel.weather else { return "bg_default"}
        
        switch weather.condition {
        case .clear, .mostlyClear: return isDay ? "bg_clear_day" : "bg_clear_night"
        case .partlyCloudy, .mostlyCloudy: return isDay ? "bg_partly_cloudy_day" : "bg_partly_cloudy_night"
        case .cloudy: return isDay ? "bg_cloudy_day" : "bg_cloudy_night"
        case .rain: return isDay ? "bg_rain_day" : "bg_rain_night"
        case .snow: return isDay ? "bg_snow_day" : "bg_snow_night"
        case .foggy: return isDay ? "bg_fog_day" : "bg_fog_night"
        default: return "bg_default"
        }
    }
    
    private func fetchInfo() async {
        await viewModel.fetchData()
        await viewModel.fetchWeather()
    }
}
