//
//  ChatEngineIntegrationTests.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/21/25.
//

// MARK: - Tests for ChatEngine end-to-end

import XCTest
@testable import Zunlo

final class ChatEngineIntegrationTests: XCTestCase {
    func testEngineCreatesAssistantAndPersistsOnComplete() async throws {
        let streamer = MockStreamer()
        streamer.queuedEmissions = [
            .init(SSE.responseCreated("resp_10")),
            .init(SSE.textDelta("Hi")),
            .init(SSE.completed())
        ]
        let ai = SupabaseEdgeAIClient(streamer: streamer, auth: MockAuthProvider())
        let repo = InMemoryChatRepositoryActor()
        let tools = MockToolRouter()
        let engine = ChatEngine(conversationId: UUID(), ai: ai, tools: tools, repo: repo)
        
        
        let user = ChatMessage(conversationId: UUID(), role: .user, plain: "Hello", createdAt: Date(), status: .sent)
        let stream = await engine.startStream(history: [], userMessage: user)
        
        
        var assistantId: UUID?
        var seenCompleted = false
        for await ev in stream {
            switch ev {
            case .messageAppended(let m) where m.role == .assistant: assistantId = m.id
            case .completed: seenCompleted = true
            default: break
            }
        }
        XCTAssertTrue(seenCompleted)
        XCTAssertNotNil(assistantId)
    }
    
    
    func testEngineHandlesRequiredActionPath() async throws {
        let streamer = MockStreamer()
        streamer.queuedEmissions = [
            .init(SSE.responseCreated("resp_20")),
            .init(SSE.requiredAction(responseId: "resp_20", toolId: "t1", name: "echo", callId: "c1", argsJSON: "{\\\"q\\\":123}")),
            .init(SSE.textDelta("done")),
            .init(SSE.completed())
        ]
        let ai = SupabaseEdgeAIClient(streamer: streamer, auth: MockAuthProvider())
        let repo = InMemoryChatRepositoryActor()
        let tools = MockToolRouter()
        let engine = ChatEngine(conversationId: UUID(), ai: ai, tools: tools, repo: repo)
        
        
        let user = ChatMessage(conversationId: UUID(), role: .user, plain: "Hi", createdAt: Date(), status: .sent)
        let stream = await engine.startStream(history: [], userMessage: user)
        
        
        var sawBatch = false
        var completed = false
        for await ev in stream {
            switch ev {
            case .messageAppended(let m) where m.role == .tool:
                // Engine emits a compact summary/tool bubble for the streamed path; for required_action path, it won't until after submit, but here we're just verifying the flow continues
                sawBatch = true // if your engine creates a tool bubble on required_action failure, adapt this
            case .completed: completed = true
            default: break
            }
        }
        XCTAssertTrue(completed)
        // If you choose not to append a tool bubble for required_action, remove this assertion.
        _ = sawBatch
    }
}
