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
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) { self.client = client }

    // MARK: - Tasks
    @discardableResult
    public func createTask(_ payload: CreateTaskPayloadWire) async throws -> TaskMutationResult {
        return try await invoke(payload, functionName: "tools/createTask")
    }

    @discardableResult
    public func updateTask(_ payload: UpdateTaskPayloadWire) async throws -> TaskMutationResult {
        return try await invoke(payload, functionName: "tools/updateTask")
    }

    @discardableResult
    public func deleteTask(_ payload: DeleteTaskPayloadWire) async throws -> TaskMutationResult {
        return try await invoke(payload, functionName: "tools/deleteTask")
    }

    // MARK: - Events
    @discardableResult
    public func createEvent(_ payload: CreateEventPayloadWire) async throws -> EventMutationResult {
        return try await invoke(payload, functionName: "tools/createEvent")
    }

    @discardableResult
    public func updateEvent(_ payload: UpdateEventPayloadWire) async throws -> EventMutationResult {
        return try await invoke(payload, functionName: "tools/updateEvent")
    }

    @discardableResult
    public func deleteEvent(_ payload: DeleteEventPayloadWire) async throws -> EventMutationResult {
        return try await invoke(payload, functionName: "tools/deleteEvent")
    }
    
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
}
