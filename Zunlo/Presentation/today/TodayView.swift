//
//  TodayView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI

struct TodayView: View {
    var namespace: Namespace.ID
    @Binding var showChat: Bool

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var upgradeFlowManager: UpgradeFlowManager
    @EnvironmentObject var upgradeReminderManager: UpgradeReminderManager
    
    @AppStorage("firstLaunchTimestamp") private var firstLaunchTimestamp: Double = 0
    @AppStorage("sessionCount") private var sessionCount = 0
    @AppStorage("hasDismissedUpgradeReminder") private var dismissed = false
    private let minSessionsBeforeShowing = 5
    private let daysUntilBanner = 3
    
    @StateObject private var viewModel: TodayViewModel
    
    @State private var showSchedule = false
    @State private var showTaskInbox = false
    @State private var showAddTask = false
    @State private var showAddEvent = false
    @State private var showRequestPush = false
    @State private var showSettings = false
    @State private var editableUserTask: UserTask?
    
    private let appState: AppState

    init(namespace: Namespace.ID,
         showChat: Binding<Bool>,
         appState: AppState) {
        self.namespace = namespace
        self._showChat = showChat
        self.appState = appState
        _viewModel = StateObject(wrappedValue: TodayViewModel(
            taskRepository: appState.userTaskRepository,
            eventRepository: appState.eventRepository,
            locationService: appState.locationService)
        )
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
    
    private var backgroundImageName: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let isDay = (6...18).contains(hour)
        
        guard let weather = viewModel.weather else { return "bg_default"}
        return "bg_clear_night"
        switch weather.condition {
        case .clear, .mostlyClear: return isDay ? "bg_clear_day" : "bg_clear_night"
        case .partlyCloudy, .mostlyCloudy: return isDay ? "bg_partly_cloudy_day" : "bg_partly_cloudy_night"
        case .cloudy: return "bg_cloudy"
        case .rain: return "bg_rain"
        case .snow: return "bg_snow"
        default: return "bg_default"
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.theme.background.ignoresSafeArea()
            NavigationStack {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 24) {
                        if let weather = viewModel.weather {
                            TodayWeatherView(weather: weather, greeting: viewModel.greeting)
                        }
                        if upgradeReminderManager.shouldShowReminder(isAnonymous: authManager.isAnonymous) {
                            showBannerSection
                        }
                        quickAddSection
                        eventsTodaySection
                        tasksTodaySection
                    }
                    .padding()
                }
                .refreshable {
                    Task {
                        await viewModel.fetchData()
                    }
                }
                .background(
                    Image(backgroundImageName)
                        .resizable()
                        .scaledToFill()
                        .overlay(Color.white.opacity(0.3))
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.4), value: backgroundImageName)
                        .ignoresSafeArea()
                )
                .navigationTitle("Zunlo")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showSchedule) {
                    CalendarScheduleContainer(
                        viewModel: CalendarScheduleViewModel(
                            repository: appState.eventRepository,
                            locationService: appState.locationService
                        )
                    )
                }
                .sheet(isPresented: $showRequestPush, onDismiss: {
                    showSchedule = true
                }, content: {
                    RequestPushPermissionsView(pushPermissionsDenied: appState.pushNotificationService.pushPermissionsDenied) {
                        appState.pushNotificationService.requestNotificationPermissions { granted in
                            showRequestPush = false
                        }
                    }
                })
                .sheet(isPresented: $showTaskInbox) {
                    TaskInboxView(repository: appState.userTaskRepository)
                }
                .sheet(isPresented: $showAddTask) {
                    AddEditTaskView(viewModel: AddEditTaskViewModel(mode: .add, repository: appState.userTaskRepository))
                }
                .sheet(item: $editableUserTask, content: { userTask in
                    AddEditTaskView(viewModel: AddEditTaskViewModel(mode: .edit(userTask), repository: appState.userTaskRepository))
                })
                .sheet(isPresented: $showAddEvent) {
                    AddEditEventView(viewModel: AddEditEventViewModel(mode: .add, repository: appState.eventRepository))
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView(authManager: appState.authManager)
                        .environmentObject(upgradeFlowManager)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "slider.horizontal.3")
                        }
                    }
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
        }
        .onAppear {
            sessionCount += 1
            if firstLaunchTimestamp == 0 {
                setFirstLaunchDate(Date())
            }
        }
        .task {
            await viewModel.fetchData()
            await viewModel.fetchWeather()
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
                Text("Events today")
                    .themedHeadline()
                
                if viewModel.todaysEvents.isEmpty {
                    Text("No events for today.")
                        .themedBody()
                        .foregroundColor(.gray)
                    
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.todaysEvents) { event in
                            EventRow(occurrence: event, onTap: { /* handle tap */ })
                        }
                    }
                    .themedBody()
                }

                Button("View full schedule") {
                    if appState.pushNotificationService.pushPermissionsGranted {
                        showSchedule = true
                    } else {
                        showRequestPush = true
                    }
                }
                .themedTertiaryButton()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .themedCard(blurBackground: true)
    }

    private var tasksTodaySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tasks today")
                    .themedHeadline()

                if viewModel.todaysTasks.isEmpty {
                    Text("No tasks for today.")
                        .themedBody()
                        .foregroundColor(.gray)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.todaysTasks) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskCompletion(for: task)
                            } onTap: {
                                editableUserTask = task
                            }
                        }
                    }
                    .themedBody()
                }

                Button("View task inbox") {
                    showTaskInbox = true
                }
                .themedTertiaryButton()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .themedCard(blurBackground: true)
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { showAddTask = true }) {
                    Label("Add task", systemImage: "plus")
                }
                .themedSecondaryButton()
                Button(action: { showAddEvent = true }) {
                    Label("Add event", systemImage: "calendar.badge.plus")
                }
                .themedSecondaryButton()
            }
        }
    }
}
