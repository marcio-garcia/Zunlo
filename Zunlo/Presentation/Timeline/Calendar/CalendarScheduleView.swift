//
//  CalendarScheduleView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/1/25.
//

import SwiftUI

struct CalendarScheduleView: View {
    @EnvironmentObject var repository: EventRepository
    
    @State private var showAddSheet = false
    @State private var editingEvent: Event?
    @State private var hasScrolledToToday = false
    
    private let days: [Date] = (-5...5)
        .compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: Date())) }
        .sorted()
    
    private var groupedEvents: [String: [Event]] {
        Dictionary(grouping: repository.events) { event in
            sectionID(Calendar.current.startOfDay(for: event.dueDate))
        }
    }
    
    private func sectionID(_ date: Date) -> String {
        date.formattedDate(dateFormat: "yyyy-MM-dd")
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
                                events: groupedEvents[sectionID(date)] ?? [],
                                onEdit: { editingEvent = $0 },
                                onDelete: { event in
                                    Task { try? await repository.delete(event) }
                                }
                            )
                            .id(sectionID(date))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await repository.fetchAll()
                    }
                    .navigationTitle("Schedule")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                withAnimation {
                                    proxy.scrollTo(sectionID(Date()), anchor: .top)
                                }
                            } label: {
                                Label("Today", systemImage: "calendar.circle")
                            }
                        }
                    }
                    .onAppear {
                        // Prevents repeated jumps when view reloads
                        if !hasScrolledToToday {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                proxy.scrollTo(sectionID(Date()), anchor: .top)
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
