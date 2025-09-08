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
    typealias A = ToolDispatchResult
    
    private let fetcher: EventFetcherService
    private let editor: EventEditorService
    private let auth: AuthProviding
    private let aiToolRouter: AIToolRouter
    
    init(
        fetcher: EventFetcherService,
        editor: EventEditorService,
        auth: AuthProviding,
        aiToolRouter: AIToolRouter
    ) {
        self.fetcher = fetcher
        self.editor = editor
        self.auth = auth
        self.aiToolRouter = aiToolRouter
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
            color: .softOrange,
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
        guard await auth.isAuthorized(), let userId = auth.userId else { return [] }
        let rawOcc = try await fetcher.fetchOccurrences(for: userId)
        let occ = try EventOccurrenceService.generate(rawOccurrences: rawOcc, in: range, addFakeToday: false)
        return []
    }
    
    func agenda(in range: Range<Date>) async throws -> A {
        var agendaRange: GetAgendaArgs.DateRange = .custom
        let today = Date().startOfDay()
        let tomorrow = today.startOfNextDay()
        let afterTomorrow = tomorrow.startOfNextDay()
        
        if range == today..<tomorrow {
            agendaRange = .today
        } else if range == tomorrow..<afterTomorrow {
            agendaRange = .tomorrow
        } else if range.lowerBound.daysInterval(to: range.upperBound) == 7 {
            agendaRange = .week
        }
        
        let agendaArgs = GetAgendaArgs(dateRange: agendaRange, start: range.lowerBound, end: range.upperBound)
        
        do {
            let args = try JSONEncoder.makeEncoder().encode(agendaArgs)
            if let argsJSON = String(data: args, encoding: .utf8) {
                let toolEnvelope = AIToolEnvelope(name: "getAgenda", argsJSON: argsJSON)
                let result = try await aiToolRouter.dispatch(toolEnvelope)
                return result
            }
        } catch {
            print(error)
        }
        return ToolDispatchResult(note: "")
    }
}

extension ToolDispatchResult: AgendaType {
    public var attributedAgenda: AttributedString? {
        return self.attributedText
    }
    
    public var agenda: String {
        return self.note
    }
}
