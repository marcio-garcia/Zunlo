//
//  TodayView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI

struct TodayView: View {
    @State private var showSchedule = false
    @State private var showTaskInbox = false
    @State private var showAddTask = false
    @State private var showAddEvent = false

    // Inject your real repositories here
    var eventRepository: EventRepository
    var taskRepository: UserTaskRepository

    var body: some View {
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
            .navigationTitle("Today")
            .sheet(isPresented: $showSchedule) {
                CalendarScheduleView(repository: eventRepository)
            }
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
    }

    private var greetingSection: some View {
        Text("Good morning! 👋")
            .font(.largeTitle)
            .fontWeight(.semibold)
    }

    private var eventsTodaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Events Today")
                .font(.headline)

            // Replace with real event occurrences for today
            Group {
                Text("\u{2022} 9:00 AM - Team Standup")
                Text("\u{2022} 2:00 PM - Therapist Appointment")
            }

            Button("View Full Schedule") {
                showSchedule = true
            }
            .font(.subheadline)
        }
    }

    private var tasksTodaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tasks Today")
                .font(.headline)

            // Replace with real filtered tasks for today
            Group {
                Text("[ ] Take medication")
                Text("[ ] Write journal entry")
            }

            Button("View Task Inbox") {
                showTaskInbox = true
            }
            .font(.subheadline)
        }
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .font(.headline)

            HStack {
                Button(action: { showAddTask = true }) {
                    Label("Add Task", systemImage: "plus")
                }
                Button(action: { showAddEvent = true }) {
                    Label("Add Event", systemImage: "calendar.badge.plus")
                }
            }
            .buttonStyle(.bordered)
        }
    }
}
