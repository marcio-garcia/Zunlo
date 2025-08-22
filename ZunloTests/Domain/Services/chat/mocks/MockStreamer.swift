//
//  MockStreamer.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/21/25.
//

// Edge Function Streaming Abstractions & Test Mocks
// Use in unit tests to simulate Supabase Functions SSE without a network.

import Foundation
import Supabase
@testable import Zunlo

// MARK: - Test Mocks

public final class MockStreamer: EdgeFunctionStreamer {
    public struct Emission {
        public let data: Data
        public init(_ s: String) { self.data = Data(s.utf8) }
    }
    
    public var queuedEmissions: [Emission] = []
    public var invokeStubs: [(name: String, bodyJSON: String)] = []
    public private(set) var setAuthTokens: [String] = []
    
    
    public init() {}
    
    
    public func setAuth(token: String) { setAuthTokens.append(token) }
    
    
    public func stream(function: String, options: FunctionInvokeOptions) -> AsyncThrowingStream<Data, Error> {
        let emissions = queuedEmissions // snapshot for this stream
        return AsyncThrowingStream { continuation in
            Task {
                for e in emissions { continuation.yield(e.data) }
                continuation.finish()
            }
        }
    }
    
    
    public func invoke(function: String, options: FunctionInvokeOptions) async throws -> EmptyResponse {
        invokeStubs.append((name: function, bodyJSON: "<unencodable>"))
        return EmptyResponse()
    }
}

public struct MockAuthProvider: AuthProvider {
    public var token: String? = "test-token"
    public init(token: String? = "test-token") { self.token = token }
    public func currentAccessToken() async throws -> String? { token }
}


// Helper to encode Any Encodable at runtime
public struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    public init(_ wrapped: Encodable) { self._encode = wrapped.encode }
    public func encode(to encoder: Encoder) throws { try _encode(encoder) }
}


// MARK: - SSE helpers (for building test frames)


public enum SSE {
    public static func event(_ name: String, json: String) -> String {
        "event: \(name)\n" + "data: \(json)\n\n"
    }
    public static func textDelta(_ text: String) -> String {
        event("response.output_text.delta", json: "{\"delta\":\"\(text.replacingOccurrences(of: "\"", with: "\\\""))\"}")
    }
    public static func responseCreated(_ id: String) -> String {
        event("response.created", json: "{\"response\":{\"id\":\"\(id)\"}}")
    }
    public static func completed() -> String { event("response.completed", json: "{}") }
    public static func functionAdded(itemId: String, name: String, callId: String) -> String {
        event("response.output_item.added", json: "{\"item\":{\"id\":\"\(itemId)\",\"type\":\"function_call\",\"name\":\"\(name)\",\"call_id\":\"\(callId)\"}}")
    }
    public static func functionArgsDelta(itemId: String, chunk: String) -> String {
        event("response.function_call_arguments.delta", json: "{\"item_id\":\"\(itemId)\",\"delta\":\"\(chunk.replacingOccurrences(of: "\"", with: "\\\""))\"}")
    }
    public static func functionArgsDone(itemId: String, argsJSON: String) -> String {
        event("response.function_call_arguments.done", json: "{\"item_id\":\"\(itemId)\",\"arguments\":\"\(argsJSON.replacingOccurrences(of: "\"", with: "\\\""))\"}")
    }
    public static func requiredAction(responseId: String, toolId: String, name: String, callId: String, argsJSON: String) -> String {
        let argsEsc = argsJSON.replacingOccurrences(of: "\"", with: "\\\"")
        let json = "{" +
        "\"response\":{\"id\":\"\(responseId)\"}," +
        "\"required_action\":{\"type\":\"submit_tool_outputs\",\"tools\":[{" +
        "\"id\":\"\(toolId)\",\"name\":\"\(name)\",\"call_id\":\"\(callId)\",\"arguments\":\"\(argsEsc)\"}]}" +
        "}"
        return event("response.required_action", json: json)
    }
}
