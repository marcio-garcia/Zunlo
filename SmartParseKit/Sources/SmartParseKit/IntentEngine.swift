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

    public func classify(_ text: String) -> CommandIntent {
        if let possibleLabels = model?.predictedLabelHypotheses(for: text, maximumCount: 3), possibleLabels.count > 0 {
            var sorted = possibleLabels.sorted { $0.value > $1.value }
            let firstLabel = sorted.removeFirst()
            if firstLabel.value > 0.6 {
                return CommandIntent(rawValue: firstLabel.key) ?? .unknown
            }
            let secondLabel = sorted.removeFirst()
            if ((firstLabel.value - secondLabel.value) / firstLabel.value) > 0.50 {
                return CommandIntent(rawValue: firstLabel.key) ?? .unknown
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
    
    private func fallbackPlanWeek(text: String) -> CommandIntent? {
        if (text.contains("plan") || text.contains("planejar") || text.contains("planeje") || text.contains("arrumar"))
            && (text.contains("week") || text.contains("semana")) {
            return .planWeek
        }
        return nil
    }
    
    private func fallbackPlanDay(text: String) -> CommandIntent? {
        if (text.contains("plan") || text.contains("planejar") || text.contains("what's on") || text.contains("show"))
            && (text.contains("today")) {
            return .planDay
        }
                
        if text.contains("planejar") && text.contains("hoje") {
            return .planDay
        }
        return nil
    }
    
    private func fallbackCreateTask(text: String) -> CommandIntent? {
        if text.starts(with: "create") || text.starts(with: "add")
            && text.starts(with: "task") {
            return .createTask
        }
            
        if text.starts(with: "criar") && text.contains("tarefa") {
            return .createTask
        }
        return nil
    }
    
    private func fallbackCreateEvent(text: String) -> CommandIntent? {
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
    
    private func fallbackUpdateTask(text: String) -> CommandIntent? {
        if text.contains("reschedule task") || text.contains("move task") || text.contains("postpone task") || text.contains("remarcar tarefa") || text.contains("mover tarefa") || text.contains("adiar tarefa") { return .rescheduleTask }
        return nil
    }
    
    private func fallbackUpdateEvent(text: String) -> CommandIntent? {
        if text.contains("reschedule event") || text.contains("move event") || text.contains("postpone event") || text.contains("remarcar evento") || text.contains("mover evento") || text.contains("adiar evento") { return .rescheduleEvent }
        return nil
    }
    
    private func fallbackShowAgenda(text: String) -> CommandIntent? {
        if text.contains("agenda") {
            return .showAgenda
        }
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
