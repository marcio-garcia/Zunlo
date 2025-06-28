//
//  TimelineScrollView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import SwiftUI

struct TimelineScrollView: View {
    @EnvironmentObject var repository: EventRepository
    @State private var showAddEvent = false
    @State private var hasScrolledToToday = false
    @State private var groupedEvents: [String: [Event]] = [:]

    // Generate sorted list of days: [-3...+3] around today
    private let days: [Date] = (-3...3)
        .compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
        .sorted()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            ForEach(days, id: \.self) { date in
                                VStack(alignment: .leading, spacing: 0) {
                                    // Section Header
                                    HStack {
                                        Text(dateString(date))
                                            .font(.largeTitle)
                                            .padding(.bottom, 2)
                                        if Calendar.current.isDateInToday(date) {
                                            Text("TODAY")
                                                .font(.headline)
                                                .foregroundColor(.accentColor)
                                                .padding(.leading)
                                        }
                                    }
                                    Divider()

                                    // Events for this date
                                    let events = groupedEvents[sectionID(date)] ?? []
                                    
                                    if events.isEmpty {
                                        Text("No events")
                                            .foregroundColor(.secondary)
                                            .padding(.vertical, 16)
                                    } else {
                                        VStack(alignment: .leading, spacing: 24) {
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
                                        .padding(.vertical)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top)
                                .id(sectionID(date))
                            }
                        }
                        .padding(.vertical, 32)
                    }

                    VStack(spacing: 12) {
                        // Floating Add Event Button
                        Button(action: { showAddEvent = true }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }

                        // Floating "Today" Button
                        Button(action: {
                            hasScrolledToToday = true
                            withAnimation {
                                proxy.scrollTo(sectionID(Date()), anchor: .top)
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
                .sheet(isPresented: $showAddEvent) {
                    AddEventView()
                }
                .onAppear {
                    updateGroupedEvents()
                    if !hasScrolledToToday {
                        DispatchQueue.main.async {
                            proxy.scrollTo(sectionID(Date()), anchor: .top)
                            hasScrolledToToday = true
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Helpers
    
    private func updateGroupedEvents() {
        let events = repository.eventsStartingFromToday()
        groupedEvents = Dictionary(grouping: events,
                                   by: { sectionID($0.dueDate) })
    }

    private func dateString(_ date: Date) -> String {
        date.formattedDate(dateFormat: "E, MMM d")
    }

    private func sectionID(_ date: Date) -> String {
        date.formattedDate(dateFormat: "yyyy-MM-dd")
    }
}
