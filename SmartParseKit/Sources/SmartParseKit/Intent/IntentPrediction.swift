//
//  IntentPrediction.swift
//  SmartParseKit
//
//  Created by Claude on 9/15/25.
//

import Foundation

public struct IntentPrediction: Identifiable {
    public let id: UUID
    public let intent: Intent
    public let confidence: Float
    public let reasoning: [String]

    public init(id: UUID, intent: Intent, confidence: Float, reasoning: [String]) {
        self.id = id
        self.intent = intent
        self.confidence = confidence
        self.reasoning = reasoning
    }
}

public struct IntentAmbiguity {
    public let predictions: [IntentPrediction]
    public let isAmbiguous: Bool
    public let threshold: Float

    public init(predictions: [IntentPrediction], threshold: Float = 0.3) {
        self.predictions = predictions.sorted { $0.confidence > $1.confidence }
        self.threshold = threshold

        // Ambiguous if we have multiple predictions and the difference between top two is small
        self.isAmbiguous = predictions.count > 1 &&
                          (predictions.first?.confidence ?? 0) - (predictions.dropFirst().first?.confidence ?? 0) < threshold
    }

    /// Get the most likely intent
    public var primaryIntent: Intent {
        return predictions.first?.intent ?? .unknown
    }

    /// Get alternative intents if ambiguous
    public var alternatives: [IntentPrediction] {
        return isAmbiguous ? Array(predictions.dropFirst()) : []
    }
}
