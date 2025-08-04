//
//  TodayView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI
import FlowNavigator

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
    
//    @State private var showSchedule = false
//    @State private var showTaskInbox = false
    @State private var showRequestPush = false
    @State private var editableUserTask: UserTask?
    
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
        ZStack(alignment: .bottomTrailing) {
            Color.theme.background.ignoresSafeArea()
            
            switch viewModel.state {
            case .empty, .loaded:
                NavigationStack {
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 24) {
                            if let weather = viewModel.weather {
                                TodayWeatherView(weather: weather, greeting: viewModel.greeting)
                            }
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
                                AnyView(CalendarScheduleContainer(
                                    viewModel: CalendarScheduleViewModel(
                                        repository: appState.eventRepository,
                                        locationService: appState.locationService
                                    )
                                ))
                            }
                        ))
                    })
//                    .sheet(isPresented: $showSchedule) {
//                        CalendarScheduleContainer(
//                            viewModel: CalendarScheduleViewModel(
//                                repository: appState.eventRepository,
//                                locationService: appState.locationService
//                            )
//                        )
//                    }
//                    .sheet(isPresented: $showRequestPush, onDismiss: {
//                        showSchedule = true
//                    }, content: {
//                        RequestPushPermissionsView(pushPermissionsDenied: appState.pushNotificationService.pushPermissionsDenied) {
//                            appState.pushNotificationService.requestNotificationPermissions { granted in
//                                showRequestPush = false
//                            }
//                        }
//                    })
//                    .sheet(isPresented: $showTaskInbox) {
//                        TaskInboxView(repository: appState.userTaskRepository)
//                    }
                    .confirmationDialog(
                        "Edit Recurring Event",
                        isPresented: $viewModel.eventEditHandler.showEditChoiceDialog,
                        titleVisibility: .visible
                    ) {
                        Button("Edit only this occurrence") {
                            viewModel.eventEditHandler.selectEditOnlyThisOccurrence()
                        }
                        Button("Edit all occurrences") {
                            viewModel.eventEditHandler.selectEditAllOccurrences()
                        }
                        Button("Cancel", role: .cancel) {
                            viewModel.eventEditHandler.showEditChoiceDialog = false
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
                        nav.showFullScreen(.eventCalendar)
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
                                nav.showSheet(.editEvent(event.id))
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
