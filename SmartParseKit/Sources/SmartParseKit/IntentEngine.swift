// The Swift Programming Language
// https://docs.swift.org/swift-book

// Sources/SmartParseKit/SmartParseKit.swift
// Entry point + key components

import Foundation
import NaturalLanguage

// MARK: - IntentEngine

public final class IntentEngine {
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

    public func classify(_ text: String) -> UserIntent {
        if let label = model?.predictedLabel(for: text) {
            return UserIntent(rawValue: label) ?? .unknown
        }
        // fallback heuristics
        let lower = text.lowercased()
        if lower.contains("plan my week") || lower.contains("planejar minha semana") { return .planWeek }
        if lower.contains("help me plan my week") { return .planWeek }
        
        if lower.contains("today") && lower.contains("agenda") { return .planDay }
        if (lower.contains("what's on") || lower.contains("show")) && lower.contains("today") || lower.contains("agenda de hoje") { return .planDay }
        
        if lower.starts(with: "create task") || lower.starts(with: "add task") || lower.starts(with: "criar tarefa") { return .createTask }
        
        if lower.contains("new event") || lower.starts(with: "create event") || lower.starts(with: "criar evento") || lower.starts(with: "agendar") { return .createEvent }
        
        if lower.contains("reschedule") || lower.contains("move") || lower.contains("postpone") || lower.contains("remarcar") || lower.contains("mover") || lower.contains("adiar") { return .updateReschedule }
        
        if lower.contains("agenda") { return .showAgenda }
        return .unknown
    }
}

// Inside SmartParseKit, e.g. add this helper:
extension IntentEngine {
    public static func bundled() -> IntentEngine {
        let url = Bundle.module.url(forResource: "ZunloIntents", withExtension: "mlmodelc")
        return IntentEngine(modelURL: url)
    }
}
