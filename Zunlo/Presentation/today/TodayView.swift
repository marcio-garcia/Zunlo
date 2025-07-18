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
    @State private var editableUserTask: UserTask?
    
    private let eventRepository: EventRepository
    private let taskRepository: UserTaskRepository
    private let locationService: LocationService
    private let pushService: PushNotificationService

    init(namespace: Namespace.ID,
         showChat: Binding<Bool>,
         eventRepository: EventRepository,
         taskRepository: UserTaskRepository,
         locationService: LocationService,
         pushService: PushNotificationService) {
        self.namespace = namespace
        self._showChat = showChat
        self.eventRepository = eventRepository
        self.taskRepository = taskRepository
        self.locationService = locationService
        self.pushService = pushService
        _viewModel = StateObject(wrappedValue: TodayViewModel(taskRepository: taskRepository, eventRepository: eventRepository))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white.ignoresSafeArea()
            NavigationStack {
                ScrollView {
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
                    CalendarScheduleView(repository: eventRepository, locationService: locationService)
                }
                .sheet(isPresented: $showRequestPush, onDismiss: {
                    showSchedule = true
                }, content: {
                    RequestPushPermissionsView(pushPermissionsDenied: pushService.pushPermissionsDenied) {
                        pushService.requestNotificationPermissions { granted in
                            showRequestPush = false
                        }
                    }
                })
                .sheet(isPresented: $showTaskInbox) {
                    TaskInboxView(repository: taskRepository)
                }
                .sheet(isPresented: $showAddTask) {
                    AddEditTaskView(viewModel: AddEditTaskViewModel(mode: .add, repository: taskRepository))
                }
                .sheet(item: $editableUserTask, content: { userTask in
                    AddEditTaskView(viewModel: AddEditTaskViewModel(mode: .edit(userTask), repository: taskRepository))
                })
                .sheet(isPresented: $showAddEvent) {
                    AddEditEventView(viewModel: AddEditEventViewModel(mode: .add, repository: eventRepository))
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
                    if pushService.pushPermissionsGranted {
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

//struct TodayView: View {
//    var namespace: Namespace.ID
//    @Binding var showChat: Bool
//    
//    @State private var todaysTasks: [UserTask] = []
//    @State private var todaysEvents: [EventOccurrence] = []
//    @State private var showSchedule = false
//    @State private var showTaskInbox = false
//    @State private var showAddTask = false
//    @State private var showAddEvent = false
//    @State private var showRequestPush = false
//
//    // Inject your real repositories here
//    var eventRepository: EventRepository
//    var taskRepository: UserTaskRepository
//    var locationService: LocationService
//    var pushService: PushNotificationService
//
//    var body: some View {
//        ZStack(alignment: .bottomTrailing) {
//            Color.white.ignoresSafeArea()
//            NavigationStack {
//                ScrollView {
//                    VStack(alignment: .leading, spacing: 24) {
//                        greetingSection
//                        eventsTodaySection
//                        tasksTodaySection
//                        quickAddSection
//                    }
//                    .padding()
//                }
//                .navigationTitle("Zunlo")
//                .navigationBarTitleDisplayMode(.inline)
//                .sheet(isPresented: $showSchedule) {
//                    CalendarScheduleView(repository: eventRepository,
//                                         locationService: locationService)
//                }
//                .sheet(isPresented: $showRequestPush, onDismiss: {
//                    showSchedule = true
//                }, content: {
//                    RequestPushPermissionsView(pushPermissionsDenied: pushService.pushPermissionsDenied) {
//                        pushService.requestNotificationPermissions { granted in
//                            showRequestPush = false
//                        }
//                    }
//                })
//                .sheet(isPresented: $showTaskInbox) {
//                    TaskInboxView(repository: taskRepository)
//                }
//                .sheet(isPresented: $showAddTask) {
//                    AddEditTaskView(viewModel: AddEditTaskViewModel(mode: .add, repository: taskRepository))
//                }
//                .sheet(isPresented: $showAddEvent) {
//                    AddEditEventView(viewModel: AddEditEventViewModel(mode: .add, repository: eventRepository))
//                }
//            }
//            Button(action: {
//                showChat = true
//            }) {
//                Image(systemName: "bubble.left.and.bubble.right.fill")
//                    .font(.system(size: 24))
//                    .foregroundColor(.white)
//                    .padding()
//                    .background(
//                        Circle()
//                            .fill(Color.accentColor)
//                            .matchedGeometryEffect(id: "chatMorph", in: namespace)
//                    )
//            }
//            .padding()
//        }
//        .onReceive(taskRepository.tasks.publisher) { tasks in
//            let today = Calendar.current.startOfDay(for: Date())
//            todaysTasks = tasks.filter {
//                guard let dueDate = $0.dueDate else { return false }
//                return Calendar.current.isDate(dueDate, inSameDayAs: today)
//            }
//        }
//        .onReceive(eventRepository.occurrences.publisher) { occurrences in
//            let today = Calendar.current.startOfDay(for: Date())
//            todaysEvents = occurrences.filter {
//                Calendar.current.isDate($0.startDate, inSameDayAs: today)
//            }
//        }
//        .task {
//            try await taskRepository.fetchAll()
//            try await eventRepository.fetchAll()
//        }
//    }
//    
//    private var greetingSection: some View {
//        Text(greetingForCurrentTime())
//            .themedTitle()
//    }
//    
//    private var eventsTodaySection: some View {
//        HStack {
//            VStack(alignment: .leading, spacing: 8) {
//                Text("Events Today")
//                    .themedHeadline()
//                
//                Group {
//                    if todaysEvents.isEmpty {
//                        Text("No events for today.")
//                            .foregroundColor(.gray)
//                    } else {
//                        ForEach(todaysEvents) { event in
//                            EventRow(occurrence: event, onTap: {
//                                // Make it possible to edit events
//                            })
//                        }
//                    }
//                }
//                .themedBody()
//                
//                Button("View Full Schedule") {
//                    if pushService.pushPermissionsGranted {
//                        showSchedule = true
//                    } else {
//                        showRequestPush = true
//                    }
//                }
//                .themedTertiaryButton()
//            }
//            Spacer()
//        }
//        .frame(maxWidth: .infinity)
//        .themedCard()
//    }
//    
//    private var tasksTodaySection: some View {
//        HStack {
//            VStack(alignment: .leading, spacing: 8) {
//                Text("Tasks Today")
//                    .themedHeadline()
//                
//                Group {
//                    if todaysTasks.isEmpty {
//                        Text("No tasks for today.")
//                            .foregroundColor(.gray)
//                    } else {
//                        ForEach(todaysTasks) { task in
//                            TaskRow(task: task)
//                        }
//                    }
//                }
//                .themedBody()
//                
//                Button("View Task Inbox") {
//                    showTaskInbox = true
//                }
//                .themedTertiaryButton()
//            }
//            Spacer()
//        }
//        .frame(maxWidth: .infinity)
//        .themedCard()
//    }
//
//    private var quickAddSection: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack {
//                Button(action: { showAddTask = true }) {
//                    Label("Add Task", systemImage: "plus")
//                }
//                .themedSecondaryButton()
//                Button(action: { showAddEvent = true }) {
//                    Label("Add Event", systemImage: "calendar.badge.plus")
//                }
//                .themedSecondaryButton()
//            }
//        }
//    }
//    
//    private func greetingForCurrentTime(date: Date = Date()) -> String {
//        let hour = Calendar.current.component(.hour, from: date)
//        
//        switch hour {
//        case 5..<12:
//            return "Good morning! 👋"
//        case 12..<17:
//            return "Good afternoon! ☀️"
//        case 17..<22:
//            return "Good evening! 🌆"
//        default:
//            return "Good night! 🌙"
//        }
//    }
//}
