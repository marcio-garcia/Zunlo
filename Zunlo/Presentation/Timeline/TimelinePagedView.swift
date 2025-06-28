//
//  TimelinePagedView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/28/25.
//

import SwiftUI

struct TimelinePagedView: View {
    @EnvironmentObject var repository: EventRepository
    @State private var newEvent = Event.empty
    @State private var showAddEvent = false
    @State private var groupedEvents: [String: [Event]] = [:]
    @State private var currentIndex = 3 // 3 is "Today" in -3...3

    // Display days from -3 to +3 around today
    private let days: [Date] = (-3...3)
        .compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
        .sorted()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $currentIndex) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, date in
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack {
                            Text(dateString(date))
                                .font(.largeTitle)
                            if Calendar.current.isDateInToday(date) {
                                Text("TODAY")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                    .padding(.leading)
                            }
                        }
                        .padding(.top, 40)

                        Divider()

                        // Events list
                        let events = groupedEvents[sectionID(date)] ?? []
                        if events.isEmpty {
                            Text("No events")
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 20) {
                                    ForEach(events) { event in
                                        HStack {
                                            Text(event.dueDate.formattedDate(dateFormat: "HH:mm"))
                                                .font(.headline)
                                                .frame(width: 60, alignment: .trailing)
                                            Text(event.title)
                                                .font(.body)
                                        }
                                    }
                                }
                                .padding(.top, 16)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onAppear(perform: updateGroupedEvents)
            .sheet(isPresented: $showAddEvent, onDismiss: addEventIfNeeded) {
                AddEventView(newEvent: $newEvent)
            }

            // Floating buttons (Add + Today)
            VStack(spacing: 16) {
                Button(action: {
                    showAddEvent = true
                }) {
                    Image(systemName: "plus")
                        .font(.title)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                        .accessibilityLabel("Add Event")
                }
                Button(action: {
                    withAnimation {
                        currentIndex = 3 // Jump to "today" (index 3)
                    }
                }) {
                    Text("⬤ Today")
                        .font(.headline)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(24)
                        .shadow(radius: 3)
                }
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func addEventIfNeeded() {
        guard !newEvent.title.isEmpty else { return }
        Task {
            do {
                try await repository.addEvent(newEvent)
                newEvent = .empty
                updateGroupedEvents()
            } catch {
                print("Error adding event: \(error)")
            }
        }
    }

    private func updateGroupedEvents() {
        let events: [Event] = repository.eventsStartingFromToday()
        groupedEvents = Dictionary(grouping: events) { (event: Event) in
            sectionID(event.dueDate)
        }
    }

    private func sectionID(_ date: Date) -> String {
        date.formattedDate(dateFormat: "yyyy-MM-dd")
    }

    private func dateString(_ date: Date) -> String {
        date.formattedDate(dateFormat: "E, MMM d")
    }
}
