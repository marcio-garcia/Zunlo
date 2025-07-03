//
//  CalendarScheduleView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/1/25.
//

import SwiftUI

import SwiftUI

struct CalendarScheduleView: View {
    @EnvironmentObject var repository: EventRepository

    @State private var showAddSheet = false
    @State private var editingEvent: Event?
    @State private var hasScrolledToToday = false

    // Pick your range, e.g., ±1 year around today
    private var range: ClosedRange<Date> {
        let cal = Calendar.current
        let start = cal.date(byAdding: .year, value: -1, to: cal.startOfDay(for: Date()))!
        let end = cal.date(byAdding: .year, value: 1, to: cal.startOfDay(for: Date()))!
        return start...end
    }

    // All unique days with at least one event (including recurrences)
    private var days: [Date] {
        repository.events.allEventDates(in: range)
    }

    // Helper to get events for a given day
    private func events(for date: Date) -> [Event] {
        repository.events.filter { $0.occurs(on: date) }
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    List {
                        ForEach(days, id: \.self) { date in
                            DaySection2View(
                                date: date,
                                isToday: Calendar.current.isDateInToday(date),
                                events: events(for: date),
                                onEdit: { editingEvent = $0 },
                                onDelete: { event in
                                    Task { try? await repository.delete(event) }
                                }
                            )
                            .id(date.formattedDate(dateFormat: "yyyy-MM-dd"))
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await repository.fetchAll()
                    }
                    .navigationTitle("Schedule")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
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
            .sheet(item: $editingEvent) { event in
                AddEventView(eventToEdit: event)
                    .environmentObject(repository)
            }
            .task {
                await repository.fetchAll()
            }
        }
    }
}
