//
//  NoopAIClient.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

import Foundation

// Offline/demo stub; swap for a real provider later.
public final class NoopAIClient: AIChatService {
    private var cancelled = false
    public init() {}

    public func cancelCurrentGeneration() { cancelled = true }

    public func generate(
        conversationId: UUID,
        history: [ChatMessage],
        userInput: String,
        attachments: [ChatAttachment],
        supportsTools: Bool
    ) -> AsyncThrowingStream<AIEvent, Error> {
        let replyId = UUID()
        cancelled = false

        return AsyncThrowingStream { continuation in
            Task {
                continuation.yield(.started(replyId: replyId))

                let lower = userInput.lowercased()
                var canned = "Got it. I’ll help with tasks and scheduling once the AI provider is connected."
                var chips: [String] = ["Break this down", "Plan my day", "Find 30-min slot"]

                if lower.contains("break") || lower.contains("subtask") {
                    canned = """
                    Here’s a suggested breakdown:
                    1) Define the outcome
                    2) List concrete steps
                    3) Estimate durations
                    4) Schedule the first step today
                    """
                    chips = ["Schedule these", "Change durations", "Save as checklist"]
                } else if lower.contains("plan") || lower.contains("schedule") {
                    canned = """
                    Proposed plan:
                    • Morning: Deep work block (90m)
                    • Afternoon: Meetings & admin (60m)
                    • Evening: Buffer / review (30m)
                    """
                    chips = ["Create events", "Adjust blocks", "Show alternatives"]
                }

                continuation.yield(.suggestions(chips))

                for token in canned.split(separator: " ") {
                    if self.cancelled { break }
                    try? await Task.sleep(nanoseconds: 18_000_000) // ~18ms
                    continuation.yield(.delta(replyId: replyId, text: token + " "))
                }

                continuation.yield(.completed(replyId: replyId))
                continuation.finish()
            }
        }
    }
    
    public func submitToolOutputs(responseId: String, outputs: [ToolOutput]) async throws {
        
    }
}
