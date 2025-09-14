//
//  AIToolService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation
import Supabase

/// Single responsibility: call /functions/v1/tools/* endpoints with typed payloads.
final public class AIToolService: AIToolServiceAPI {
    private let userId: UUID
    private let client: SupabaseClient
    private let toolRepo: DomainRepositories
    
    init(userId: UUID, toolRepo: DomainRepositories, client: SupabaseClient) {
        self.userId = userId
        self.client = client
        self.toolRepo = toolRepo
    }

    // MARK: - Tasks
    @discardableResult
    public func createTask(_ payload: CreateTaskPayloadWire) async throws -> TaskMutationResult {
        let body = try JSONEncoder.makeEncoder(taskPriorityEncoding: .string).encode(payload)
        return try await invoke(body: body, functionName: "tools/createTask")
    }

    @discardableResult
    public func updateTask(_ payload: UpdateTaskPayloadWire) async throws -> TaskMutationResult {
        let body = try JSONEncoder.makeEncoder(taskPriorityEncoding: .string).encode(payload)
        return try await invoke(body: body, functionName: "tools/updateTask")
    }

    @discardableResult
    public func deleteTask(_ payload: DeleteTaskPayloadWire) async throws -> TaskMutationResult {
        let body = try JSONEncoder.makeEncoder(taskPriorityEncoding: .string).encode(payload)
        return try await invoke(body: body, functionName: "tools/deleteTask")
    }

    // MARK: - Events
    @discardableResult
    public func createEvent(_ payload: CreateEventPayloadWire) async throws -> EventMutationResult {
        let body = try JSONEncoder.makeEncoder().encode(payload)
        return try await invoke(body: body, functionName: "tools/createEvent")
    }

    @discardableResult
    public func updateEvent(_ payload: UpdateEventPayloadWire) async throws -> EventMutationResult {
        let body = try JSONEncoder.makeEncoder().encode(payload)
        return try await invoke(body: body, functionName: "tools/updateEvent")
    }

    @discardableResult
    public func deleteEvent(_ payload: DeleteEventPayloadWire) async throws -> EventMutationResult {
        let body = try JSONEncoder.makeEncoder().encode(payload)
        return try await invoke(body: body, functionName: "tools/deleteEvent")
    }
    
    @discardableResult
    public func getAgenda(args: GetAgendaArgs, calculatedRange: Range<Date>, timezone: TimeZone) async throws -> AgendaRenderParts {
//        let agendaComputer = LocalAgendaComputer(userId: userId, toolRepo: toolRepo)
//        let result = try await agendaComputer.computeAgenda(range: calculatedRange, timezone: timezone)
//        let formatted: AgendaRenderParts
//        if args.dateRange == .week {
//            formatted = AgendaRenderer.renderWeekParts(result)
//        } else {
//            formatted = AgendaRenderer.renderParts(result, agendaRange: args.dateRange)
//        }
//        return formatted
        
        return AgendaRenderParts(attributed: AttributedString(), text: "", json: "", schema: "")
    }
    
    @discardableResult
    public func planWeek(
        userId: UUID,
        start: Date,
        horizonDays: Int,
        timezone: TimeZone,
        objectives: [String],
        constraints: Constraints?
    ) async throws -> ProposedPlan {
//        let agendaComputer = LocalAgendaComputer(userId: userId, toolRepo: toolRepo)
//        let weekPlanner = LocalWeekPlanner(userId: userId, agenda: agendaComputer, toolRepo: toolRepo)
//        return try await weekPlanner.proposePlan(
//            start: start,
//            horizonDays: horizonDays,
//            timezone: .current,
//            objectives: objectives,
//            constraints: constraints
//        )
        
        return ProposedPlan(start: Date(), end: Date(), blocks: [], notes: [])
    }
    
    // Receives Encodable to be encoded by the 'invoke' function
    private func invoke<T: Encodable, R: Decodable>(_ payload: T, functionName: String) async throws -> R {
        do {
            let response = try await client.functions
                .invoke(
                    functionName,
                    options: FunctionInvokeOptions(
                        body: payload
                    ),
                    decode: { data, response in
                        try JSONDecoder.decoder().decode(R.self, from: data)
                    }
                )
            return response
        } catch FunctionsError.httpError(let code, let data) {
            print("Function returned code \(code) with response \(String(data: data, encoding: .utf8) ?? "")")
            throw FunctionsError.httpError(code: code, data: data)
        } catch FunctionsError.relayError {
            print("Relay error")
            throw FunctionsError.relayError
        } catch {
            print("Other error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Receives Data, so you have to encode first
    private func invoke<R: Decodable>(body: Data, functionName: String) async throws -> R {
        do {
            let response = try await client.functions
                .invoke(
                    functionName,
                    options: FunctionInvokeOptions(
                        body: body
                    ),
                    decode: { data, response in
                        try JSONDecoder.decoder().decode(R.self, from: data)
                    }
                )
            return response
        } catch FunctionsError.httpError(let code, let data) {
            print("Function returned code \(code) with response \(String(data: data, encoding: .utf8) ?? "")")
            throw FunctionsError.httpError(code: code, data: data)
        } catch FunctionsError.relayError {
            print("Relay error")
            throw FunctionsError.relayError
        } catch {
            print("Other error: \(error.localizedDescription)")
            throw error
        }
    }

}
