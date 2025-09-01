//
//  SPEventStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/1/25.
//

import Foundation
import SmartParseKit

final class SPEventStore: EventStore {

    typealias E = AddEventInput
    
    private let fetcher: EventFetcherService
    private let editor: EventEditorService
    private let auth: AuthProviding
    
    init(
        fetcher: EventFetcherService,
        editor: EventEditorService,
        auth: AuthProviding
    ) {
        self.fetcher = fetcher
        self.editor = editor
        self.auth = auth
    }

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
    ) async throws -> AddEventInput {
        guard let userId = auth.userId else {
            throw LocalDBError.unauthorized
        }
        let now = Date()
        let input = AddEventInput(
            id: UUID(),
            userId: userId,
            title: title,
            notes: nil,
            startDate: start,
            endDate: end,
            isRecurring: isRecurring,
            location: nil,
            color: .yellow,
            reminderTriggers: nil,
            recurrenceType: recurrenceType,
            recurrenceInterval: recurrenceInterval,
            byWeekday: byWeekday,
            byMonthday: byMonthday,
            until: until,
            count: count,
            isCancelled: false
        )
        try await editor.add(input)
        return input
    }

    func updateEvent(id: UUID, start: Date, end: Date) async throws {
        guard let rawOcc = try await fetcher.fetchOccurrences(id: id) else {
            throw LocalDBError.notFound
        }
//        let occ = try EventOccurrenceService.generate(rawOccurrences: [rawOcc], in: range)
        // TODO: make SmartParseKit find out whether the edit is for all, single, override or this and future
    }

    func updateEventMetadata(id: UUID, newTitle: String?) async throws {
        
    }
    
    func events(in range: Range<Date>) async throws -> [AddEventInput] {
        []
    }
}
