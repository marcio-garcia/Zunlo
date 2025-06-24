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
    @State private var newEvent = NewEventDraft()
    
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
                                        ForEach(repository.events) { event in
                                            HStack {
                                                if let date = event.dueDate?.formatted() {
                                                    Text(date.isEmpty ? "Not set" : date)
                                                        .font(.headline)
                                                        .frame(width: 60, alignment: .trailing)
                                                }
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
        // Only add if fields are filled in, or implement custom validation
        if !newEvent.title.isEmpty {
            repository.addEvent(title: newEvent.title, dueDate: newEvent.dueDate)
            newEvent.title = ""
        }
    }
    
    private func dateString(_ date: Date) -> String {
        return date.formatted(dateFormat: "E, MMM d")
    }
    
    // Stable section IDs for ScrollViewReader
    private func sectionID(_ date: Date) -> String {
        return date.formatted(dateFormat: "yyyy-MM-dd")
    }
    
    // Dummy events by date for illustration
    func events(for date: Date) -> [EventEntity] {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return [
                EventEntity(title: "☕ Breakfast", dueDate: Date()),
                EventEntity(title: "Meeting with Jen", dueDate: Date()),
                EventEntity(title: "Lunch", dueDate: Date()),
                EventEntity(title: "Doctor", dueDate: Date())
            ]
        } else if cal.isDate(date, inSameDayAs: cal.date(byAdding: .day, value: 1, to: Date())!) {
            return [
                EventEntity(title: "Gym", dueDate: Date()),
                EventEntity(title: "Study", dueDate: Date())
            ]
        } else {
            return [
                EventEntity(title: "Open day!", dueDate: Date()),
                EventEntity(title: "Wind down", dueDate: Date())
            ]
        }
    }
}
