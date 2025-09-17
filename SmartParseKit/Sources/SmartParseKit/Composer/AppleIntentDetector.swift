// The Swift Programming Language
// https://docs.swift.org/swift-book

// Sources/SmartParseKit/SmartParseKit.swift
// Entry point + key components

import Foundation
import NaturalLanguage

public protocol IntentDetector {
    func detectLanguage(_ text: String) -> NLLanguage
    func classify(_ text: String) -> Intent
}

public final class AppleIntentDetector: IntentDetector {
    private let model: NLModel?

    public init(modelURL: URL? = nil) {
        if let url = modelURL, let m = try? NLModel(contentsOf: url) {
            model = m
        } else {
            model = nil
        }
    }

    public func detectLanguage(_ text: String) -> NLLanguage {
        let r = NLLanguageRecognizer()
        r.processString(text)
        return r.dominantLanguage ?? .english
    }

    public func classify(_ text: String) -> Intent {
        var intent: Intent?
        if let possibleLabels = model?.predictedLabelHypotheses(for: text, maximumCount: 3), possibleLabels.count > 0 {
            var sorted = possibleLabels.sorted { $0.value > $1.value }
            let firstLabel = sorted.removeFirst()
            intent = Intent(rawValue: firstLabel.key) ?? .unknown
        }
        return intent ?? .unknown
    }
}

// Inside SmartParseKit, e.g. add this helper:
extension AppleIntentDetector {
    public static func bundled() -> AppleIntentDetector {
        let url = Bundle.module.url(forResource: "ZunloIntents", withExtension: "mlmodelc")
        return AppleIntentDetector(modelURL: url)
    }
}
