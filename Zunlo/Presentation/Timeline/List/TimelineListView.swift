//
//  TimelineListView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/30/25.
//

import SwiftUI

struct TimelineListView: View {
    @EnvironmentObject var repository: EventRepository

    @State private var showAddSheet = false
    @State private var editingEvent: Event?
    @State private var expandedSection: String

    private let days: [Date] = (-3...3)
        .compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: Date())) }
        .sorted()

    init() {
        let todayID = Calendar.current.startOfDay(for: Date())
        _expandedSection = State(initialValue: todayID.formattedDate(dateFormat: "yyyy-MM-dd"))
    }

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
            List {
                ForEach(days, id: \.self) { date in
                    let id = sectionID(date)
                    let isToday = Calendar.current.isDateInToday(date)
                    let events = groupedEvents[id] ?? []
                    DaySectionView(
                        date: date,
                        isToday: isToday,
                        events: events,
                        expanded: expandedSection == id,
                        onHeaderTap: {
                            withAnimation {
                                if expandedSection == id {
                                    expandedSection = ""
                                } else {
                                    expandedSection = id
                                }
                            }
                        },
                        onEdit: { event in
                            editingEvent = event
                        },
                        onDelete: { event in
                            Task { try? await repository.delete(event) }
                        }
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add Event", systemImage: "plus")
                    }
                }
            }
            .refreshable {
                await repository.fetchAll()
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
