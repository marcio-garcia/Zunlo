//
//  CalendarScheduleView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/1/25.
//

import SwiftUI

enum EditMode {
    case onlyThis
    case all
}

struct CalendarScheduleView: View {
    @EnvironmentObject var repository: EventRepository
    
    @State private var hasScrolledToToday = false
    @State private var showAddSheet = false
    @State private var editingEvent: Event?
    @State private var editingInstanceDate: Date? // The selected instance date
    @State private var showEditOptions = false // Controls the confirmation dialog
    @State private var editMode: EditMode? // Enum: .onlyThis or .all
    @State private var pendingEvent: Event? = nil
    @State private var pendingInstanceDate: Date? = nil

    // Pick your range, e.g., ±1 year around today
    private var range: ClosedRange<Date> {
        let today = Date()
        let cal = Calendar.current
        let start = cal.date(byAdding: .year, value: -1, to: cal.startOfDay(for: today))!
        let end = cal.date(byAdding: .year, value: 1, to: cal.startOfDay(for: today))!
        return start...end
    }
    
    // All unique days with at least one event (including recurrences)
    private var days: [Date] {
        repository.allEventDates(in: range)
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    CalendarDayListView(
                        days: days,
                        repository: repository,
                        onEdit: { event, date in
                            if event.recurrence != .none {
                                pendingEvent = event
                                pendingInstanceDate = date
                                showEditOptions = true
                            } else {
                                editingEvent = event
                            }
                        },
                        onDelete: { event in
                            Task { try? await repository.delete(event) }
                        }
                    )
                    .refreshable { await repository.fetchAll() }
                    .navigationTitle("Schedule")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                withAnimation {
                                    if let today = days.first(where: { Calendar.current.isDateInToday($0) }) {
                                        proxy.scrollTo(today.formattedDate(dateFormat: "yyyy-MM-dd"), anchor: .top)
                                    }
                                }
                            } label: {
                                Label("Today", systemImage: "calendar.circle")
                            }
                            .disabled(!days.contains(where: { Calendar.current.isDateInToday($0) }))
                        }
                    }
                    .onAppear {
                        if !hasScrolledToToday,
                           let today = days.first(where: { Calendar.current.isDateInToday($0) }) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                proxy.scrollTo(today.formattedDate(dateFormat: "yyyy-MM-dd"), anchor: .top)
                                hasScrolledToToday = true
                            }
                        }
                    }
                    
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .bold))
                            .frame(width: 56, height: 56)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                            .accessibilityLabel("Add Event")
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEventView()
                    .environmentObject(repository)
            }
            .confirmationDialog("Edit Recurring Event", isPresented: $showEditOptions, titleVisibility: .visible) {
                Button("Edit only this event") {
                    editMode = .onlyThis
                    editingEvent = pendingEvent
                    editingInstanceDate = pendingInstanceDate
                    pendingEvent = nil
                    pendingInstanceDate = nil
                }
                Button("Edit all events") {
                    editMode = .all
                    editingEvent = pendingEvent
                    editingInstanceDate = pendingInstanceDate
                    pendingEvent = nil
                    pendingInstanceDate = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingEvent = nil
                    pendingInstanceDate = nil
                    editMode = nil
                }
            }
            .sheet(item: $editingEvent) { event in
                if editMode == .onlyThis, let instanceDate = editingInstanceDate {
                    AddEventView(
                        eventToEdit: Event(
                            id: UUID(),
                            userId: event.userId,
                            title: event.title,
                            createdAt: event.createdAt,
                            dueDate: instanceDate.settingTimeFrom(event.dueDate),
                            recurrence: .none,
                            exceptions: [],
                            isComplete: event.isComplete
                        ),
                        parentEventForException: event,
                        overrideDate: instanceDate
                    )
                    .environmentObject(repository)
                    .onDisappear {
                        editMode = nil
                        editingInstanceDate = nil
                    }
                } else if editMode == .all, let instanceDate = editingInstanceDate {
                    // Edit all events (prefill with tapped date)
                    AddEventView(
                        eventToEdit: event,
                        occurrenceDate: instanceDate // prefill date with the tapped occurrence
                    )
                    .environmentObject(repository)
                    .onDisappear {
                        editMode = nil
                        editingInstanceDate = nil
                    }
                }  else {
                    AddEventView(eventToEdit: event)
                        .environmentObject(repository)
                        .onDisappear {
                            editMode = nil
                            editingInstanceDate = nil
                        }
                }
            }
            .task {
                try? await repository.synchronize()
                await repository.fetchAll()
            }
        }
    }
}
