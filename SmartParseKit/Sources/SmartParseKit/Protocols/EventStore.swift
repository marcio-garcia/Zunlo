//
//  EventStore.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

// MARK: - Repository Protocols your app should conform to

import Foundation

/// Conform your app's Event model to this to use SmartParseKit directly.
public protocol EventType {
    var id: UUID { get }
    var title: String { get }
    var startDate: Date { get }
    var endDate: Date { get }
    var isRecurring: Bool { get }
    var recurrenceType: String? { get }
    var recurrenceInterval: Int? { get }
    var byWeekday: [Int]? { get }
    var byMonthday: [Int]? { get }
    var until: Date? { get }
    var count: Int? { get }
}

public protocol EventStore {
    associatedtype E: EventType
    @discardableResult
    func createEvent(
        title: String,
        start: Date,
        end: Date,
        isRecurring: Bool,
        recurrenceType: String?,
        recurrenceInterval: Int?,
        byWeekday: [Int]?,
        byMonthday: [Int]?,
        until: Date?,
        count: Int?
    ) async throws -> E
    func events(in range: Range<Date>) async throws -> [E]
    func updateEvent(id: UUID, start: Date, end: Date) async throws
    func updateEventMetadata(id: UUID, newTitle: String?) async throws
}

public extension EventStore {
    @discardableResult
    func createEvent(
        title: String,
        start: Date,
        end: Date,
        isRecurring: Bool,
        recurrenceType: String? = nil,
        recurrenceInterval: Int? = nil,
        byWeekday: [Int]? = nil,
        byMonthday: [Int]? = nil,
        until: Date? = nil,
        count: Int? = nil
    ) async throws -> E {
        try await createEvent(
            title: title,
            start: start,
            end: end,
            isRecurring: isRecurring,
            recurrenceType: recurrenceType,
            recurrenceInterval: recurrenceInterval,
            byWeekday: byWeekday,
            byMonthday: byMonthday,
            until: until,
            count: count
        )
    }
}
