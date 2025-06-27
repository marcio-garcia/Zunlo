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
    @State private var newEvent = Event.empty
    
    // Generate a list of days: [-2, -1, 0, +1, +2] around today
    let days: [Date] = ( -3...3 ).map { Calendar.current.date(byAdding: .day, value: $0, to: Date())! }

    var body: some View {
        NavigationView {
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
                                    VStack(alignment: .leading, spacing: 24) {
                                        ForEach(repository.eventsStartingFromToday()) { event in
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
                                    Button(action: { showAddEvent = true }) {
                                        Text("+ Add event")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                            .padding(.top)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top)
                                .id(sectionID(date))
                            }
                        }
                        .padding(.vertical, 32)
                    }
                    // Floating "Today" button
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
                    .padding()
                }
                .sheet(isPresented: $showAddEvent, onDismiss: addEventIfNeeded) {
                    AddEventView(newEvent: $newEvent)
                }
                .onAppear {
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
    
    private func addEventIfNeeded() {
        if !newEvent.title.isEmpty {
            Task {
                do {
                    try await repository.addEvent(newEvent)
                    newEvent.title = ""
                } catch {
                    throw error
                }
            }
        }
    }
    
    private func dateString(_ date: Date) -> String {
        return date.formattedDate(dateFormat: "E, MMM d")
    }
    
    // Stable section IDs for ScrollViewReader
    private func sectionID(_ date: Date) -> String {
        return date.formattedDate(dateFormat: "yyyy-MM-dd")
    }
}
