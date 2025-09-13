// The Swift Programming Language
// https://docs.swift.org/swift-book

// Sources/SmartParseKit/SmartParseKit.swift
// Entry point + key components

import Foundation
import NaturalLanguage

// MARK: - IntentEngine

public final class IntentDetector {
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
        var intent: CommandIntent?
        if let possibleLabels = model?.predictedLabelHypotheses(for: text, maximumCount: 3), possibleLabels.count > 0 {
            var sorted = possibleLabels.sorted { $0.value > $1.value }
            let firstLabel = sorted.removeFirst()
            if firstLabel.value > 0.6 {
                intent = CommandIntent(rawValue: firstLabel.key) ?? .unknown
            }
            let secondLabel = sorted.removeFirst()
            if ((firstLabel.value - secondLabel.value) / firstLabel.value) > 0.50 {
                intent = CommandIntent(rawValue: firstLabel.key) ?? .unknown
            }
        }
        // fallback heuristics
        let lower = text.lowercased()
        if let i = intent, i == .updateTask || i == .updateEvent {
            if let i = fallbackRescheduleTask(text: lower) { intent = i }
            if let i = fallbackRescheduleEvent(text: lower) { intent = i }
        } else  {
            if let i = fallbackPlanWeek(text: lower) { intent = i }
            if let i = fallbackPlanDay(text: lower) { intent = i  }
            if let i = fallbackCreateTask(text: lower) { intent = i  }
            if let i = fallbackCreateEvent(text: lower) { intent = i  }
            if let i = fallbackUpdateTask(text: lower) { intent = i  }
            if let i = fallbackUpdateEvent(text: lower) { intent = i  }
            if let i = fallbackRescheduleTask(text: lower) { intent = i }
            if let i = fallbackRescheduleEvent(text: lower) { intent = i }
            if let i = fallbackShowAgenda(text: lower) { intent = i  }
        }
        
        if let i = intent {
            return i
        }
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
        if (text.contains("change") || text.contains("edit") || text.contains("alterar") || text.contains("editar") || text.contains("edite")) && (text.contains("task") || text.contains("tarefa")) { return .updateTask }
        return nil
    }
    
    private func fallbackUpdateEvent(text: String) -> CommandIntent? {
        if (text.contains("change") || text.contains("alterar")) && (text.contains("event") || text.contains("evento")) { return .updateEvent }
        return nil
    }
    
    private func fallbackRescheduleTask(text: String) -> CommandIntent? {
        if (text.contains("reschedule") || text.contains("move") || text.contains("postpone") || text.contains("remarcar") || text.contains("mover") || text.contains("adiar")) && (text.contains("task") || text.contains("tarefa")) { return .rescheduleTask }
        return nil
    }
    
    private func fallbackRescheduleEvent(text: String) -> CommandIntent? {
        if (text.contains("reschedule") || text.contains("move") || text.contains("postpone") || text.contains("remarcar") || text.contains("mover") || text.contains("adiar")) && (text.contains("event") || text.contains("evento")) {
            return .rescheduleEvent
        }
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
extension IntentDetector {
    public static func bundled() -> IntentDetector {
        let url = Bundle.module.url(forResource: "ZunloIntents", withExtension: "mlmodelc")
        return IntentDetector(modelURL: url)
    }
}
