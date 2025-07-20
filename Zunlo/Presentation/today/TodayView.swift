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
            eventRepository: appState.eventRepository)
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white.ignoresSafeArea()
            NavigationStack {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 24) {
                        greetingSection
                        eventsTodaySection
                        tasksTodaySection
                        quickAddSection
                    }
                    .padding()
                }
                .navigationTitle("Zunlo")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showSchedule) {
                    CalendarScheduleView(repository: appState.eventRepository, locationService: appState.locationService)
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
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Sign Out", systemImage: "gear")
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
        .task {
            await viewModel.fetchData()
        }
        .errorAlert(viewModel.errorHandler)
    }

    private var greetingSection: some View {
        Text(viewModel.greeting)
            .themedTitle()
    }

    private var eventsTodaySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Events Today")
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

                Button("View Full Schedule") {
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
        .themedCard()
    }

    private var tasksTodaySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tasks Today")
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

                Button("View Task Inbox") {
                    showTaskInbox = true
                }
                .themedTertiaryButton()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .themedCard()
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { showAddTask = true }) {
                    Label("Add Task", systemImage: "plus")
                }
                .themedSecondaryButton()
                Button(action: { showAddEvent = true }) {
                    Label("Add Event", systemImage: "calendar.badge.plus")
                }
                .themedSecondaryButton()
            }
        }
    }
}
