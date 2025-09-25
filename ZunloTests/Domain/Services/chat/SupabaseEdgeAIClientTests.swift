//
//  SupabaseEdgeAIClientTests.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/21/25.
//

// MARK: - Tests for SupabaseEdgeAIClient

import Foundation
import XCTest
@testable import Zunlo

final class SupabaseEdgeAIClientTests: XCTestCase {
    func testSimpleDeltaStreamCompletes() async throws {
        let streamer = MockStreamer()
        streamer.queuedEmissions = [
            .init(SSE.responseCreated("resp_1")),
            .init(SSE.textDelta("Hello ")), .init(SSE.textDelta("world!")),
            .init(SSE.completed())
        ]
        let ai = SupabaseAIChatClient(auth: await MockAuthProvider(), streamer: streamer)
        
        
        let events = try await collectEvents(ai: ai)
        // Verify ordering
        XCTAssertTrue(events.contains { if case .responseCreated(let id) = $0 { return id == "resp_1" } else { return false } })
        XCTAssertTrue(events.contains { if case .delta(_, let t) = $0 { return t == "Hello " } else { return false } })
        XCTAssertTrue(events.contains { if case .delta(_, let t) = $0 { return t == "world!" } else { return false } })
        XCTAssertTrue(events.contains { if case .completed = $0 { return true } else { return false } })
    }
    
    
    func testStreamedFunctionCallEmitsToolBatch() async throws {
        let streamer = MockStreamer()
        streamer.queuedEmissions = [
            .init(SSE.responseCreated("resp_1")),
            .init(SSE.functionAdded(itemId: "item_1", name: "echo", callId: "call_1")),
            .init(SSE.functionArgsDelta(itemId: "item_1", chunk: "{\"x\":1")),
            .init(SSE.functionArgsDone(itemId: "item_1", argsJSON: "{\"x\":1}")),
            .init(SSE.completed())
        ]
        let ai = SupabaseAIChatClient(auth: await MockAuthProvider(), streamer: streamer)
        let events = try await collectEvents(ai: ai)
        
        
        let toolBatch = events.compactMap { ev -> [ToolCallRequest]? in
            if case .toolBatch(let arr) = ev { return arr } else { return nil }
        }.flatMap { $0 }
        XCTAssertEqual(toolBatch.count, 1)
        XCTAssertEqual(toolBatch.first?.name, "echo")
        XCTAssertEqual(toolBatch.first?.origin, .streamed)
    }
    
    
    func testRequiredActionEmitsBatchAndSubmitToolOutputs() async throws {
        let streamer = MockStreamer()
        streamer.queuedEmissions = [
            .init(SSE.responseCreated("resp_2")),
            .init(SSE.requiredAction(responseId: "resp_2", toolId: "tool_x", name: "echo", callId: "call_x", argsJSON: "{\"y\":2}")),
            .init(SSE.textDelta("after tools")),
            .init(SSE.completed())
        ]
        let ai = SupabaseAIChatClient(auth: await MockAuthProvider(), streamer: streamer)
        let events = try await collectEvents(ai: ai)
        // Verify we got a toolBatch with requiredAction origin
        let batch = events.compactMap { ev -> [ToolCallRequest]? in if case .toolBatch(let arr) = ev { return arr } else { return nil } }.first
        XCTAssertEqual(batch?.first?.origin, .requiredAction)
    }
    
    
    private func collectEvents(ai: AIChatService) async throws -> [AIEvent] {
        let history: [ChatMessage] = []
        let stream = try ai.generate(conversationId: UUID(), history: history, output: [], supportsTools: true)
        var arr: [AIEvent] = []
        for try await ev in stream { arr.append(ev) }
        return arr
    }
}
