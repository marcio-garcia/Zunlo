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
    
    @State private var showSchedule = false
    @State private var showTaskInbox = false
    @State private var showAddTask = false
    @State private var showAddEvent = false
    @State private var showRequestPush = false

    // Inject your real repositories here
    var eventRepository: EventRepository
    var taskRepository: UserTaskRepository
    var locationService: LocationService
    var pushService: PushNotificationService

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white.ignoresSafeArea()
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        eventsTodaySection
                        tasksTodaySection
                        quickAddSection
                    }
                    .padding()
                }
                .navigationTitle(greetingForCurrentTime())
                .sheet(isPresented: $showSchedule) {
                    CalendarScheduleView(repository: eventRepository,
                                         locationService: locationService)
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
                .sheet(isPresented: $showAddEvent) {
                    AddEditEventView(viewModel: AddEditEventViewModel(mode: .add, repository: eventRepository))
                }
            }
            Button(action: {
                showChat = true
            }) {
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
    }

    private var eventsTodaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Events Today")
                .themedHeadline()

            // Replace with real event occurrences for today
            Group {
                Text("\u{2022} 9:00 AM - Team Standup")
                Text("\u{2022} 2:00 PM - Therapist Appointment")
            }
            .themedBody()

            Button("View Full Schedule") {
                if pushService.pushPermissionsGranted {
                    showSchedule = true
                } else {
                    showRequestPush = true
                }
            }
            .themedPrimaryButton()
        }
        .themedCard()
    }

    private var tasksTodaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tasks Today")
                .themedHeadline()

            // Replace with real filtered tasks for today
            Group {
                Text("[ ] Take medication")
                Text("[ ] Write journal entry")
            }
            .themedBody()
            
            Button("View Task Inbox") {
                showTaskInbox = true
            }
            .font(AppFont.caption())
        }
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
    
    private func greetingForCurrentTime(date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        
        switch hour {
        case 5..<12:
            return "Good morning! 👋"
        case 12..<17:
            return "Good afternoon! ☀️"
        case 17..<22:
            return "Good evening! 🌆"
        default:
            return "Good night! 🌙"
        }
    }
}
