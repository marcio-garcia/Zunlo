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
        if let possibleLabels = model?.predictedLabelHypotheses(for: text, maximumCount: 3) {
            let sorted = possibleLabels.sorted { $0.value > $1.value }
            for label in sorted {
                if label.value > 0.6 {
                    return UserIntent(rawValue: label.key) ?? .unknown
                }
                // ask for clarification
            }
        }
        // fallback heuristics
        let lower = text.lowercased()
        if let intent = fallbackPlanWeek(text: lower) { return intent }
        if let intent = fallbackPlanDay(text: lower) { return intent }
        if let intent = fallbackCreateTask(text: lower) { return intent }
        if let intent = fallbackCreateEvent(text: lower) { return intent }
        if let intent = fallbackUpdateTask(text: lower) { return intent }
        if let intent = fallbackUpdateEvent(text: lower) { return intent }
        if let intent = fallbackShowAgenda(text: lower) { return intent }
        
        return .unknown
    }
    
    private func fallbackPlanWeek(text: String) -> UserIntent? {
        if text.contains("plan") && text.contains("week") {
            return .planWeek
        }
        if text.contains("week") || text.contains("semana") {
            return .planWeek
        }
        return nil
    }
    
    private func fallbackPlanDay(text: String) -> UserIntent? {
        if (text.contains("plan") || text.contains("planejar") || text.contains("what's on") || text.contains("show"))
            && (text.contains("today")) {
            return .planDay
        }
                
        if text.contains("planejar") && text.contains("hoje") {
            return .planDay
        }
        return nil
    }
    
    private func fallbackCreateTask(text: String) -> UserIntent? {
        if text.starts(with: "create") || text.starts(with: "add")
            && text.starts(with: "task") {
            return .createTask
        }
            
        if text.starts(with: "criar") && text.contains("tarefa") {
            return .createTask
        }
        return nil
    }
    
    private func fallbackCreateEvent(text: String) -> UserIntent? {
        if (text.contains("new") || text.starts(with: "create"))
            && text.contains("event") {
            return .createEvent
        }
        
        if text.starts(with: "criar") && text.contains("evento") {
            return .createEvent
        }
        
        if text.starts(with: "agendar") {
            return .createEvent
        }
        return nil
    }
    
    private func fallbackUpdateTask(text: String) -> UserIntent? {
        if text.contains("reschedule task") || text.contains("move task") || text.contains("postpone task") || text.contains("remarcar tarefa") || text.contains("mover tarefa") || text.contains("adiar tarefa") { return .rescheduleTask }
        return nil
    }
    
    private func fallbackUpdateEvent(text: String) -> UserIntent? {
        if text.contains("reschedule event") || text.contains("move event") || text.contains("postpone event") || text.contains("remarcar evento") || text.contains("mover evento") || text.contains("adiar evento") { return .rescheduleEvent }
        return nil
    }
    
    private func fallbackShowAgenda(text: String) -> UserIntent? {
        if text.contains("agenda") { return .showAgenda }
        return nil
    }
}

// Inside SmartParseKit, e.g. add this helper:
extension IntentEngine {
    public static func bundled() -> IntentEngine {
        let url = Bundle.module.url(forResource: "ZunloIntents", withExtension: "mlmodelc")
        return IntentEngine(modelURL: url)
    }
}
