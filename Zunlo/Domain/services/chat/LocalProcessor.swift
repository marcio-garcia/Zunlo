//
//  LocalProcessor.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/22/25.
//

import Foundation
import SwiftUI
import SmartParseKit
import LoggingKit
import GlowUI

/// Handles local NLP processing and tool execution (complete local flow)
actor LocalProcessor {
    private let nlpService: NLProcessing
    private let localTools: Tools
    private let calendar: Calendar

    init(nlpService: NLProcessing, localTools: Tools, calendar: Calendar) {
        self.nlpService = nlpService
        self.localTools = localTools
        self.calendar = calendar
    }

    /// Process user input with NLP and return command contexts
    func processInput(_ text: String, referenceDate: Date = Date()) async throws -> [CommandContext] {
        let parseResults = try await nlpService.process(text: text, referenceDate: referenceDate)
        return parseResults.map { CommandContext.from(parseResult: $0) }
    }

    /// Execute a command context through local tools
    func execute(_ context: CommandContext) async throws -> ToolResult {
        switch context.intent {
        case .createTask: return await localTools.createTask(context)
        case .createEvent: return await localTools.createEvent(context)
        case .updateEvent: return await localTools.updateEvent(context)
        case .updateTask: return await localTools.updateTask(context)
        case .rescheduleTask: return await localTools.rescheduleTask(context)
        case .rescheduleEvent: return await localTools.rescheduleEvent(context)
        case .cancelTask: return await localTools.cancelTask(context)
        case .cancelEvent: return await localTools.cancelEvent(context)
        case .plan: return await localTools.planWeek(context)
        case .view: return await localTools.showAgenda(context)
        case .unknown: return await localTools.unknown(context)
        }
    }

    /// Create disambiguation message for intent ambiguity
    func createIntentDisambiguationMessage(context: CommandContext) -> ToolResult {
        guard let intentAmbiguity = context.intentAmbiguity else {
            let label = createContextLabel(context: context)
            let options = [ChatMessageActionAlternative(id: UUID(), parseResultId: context.id, intentOption: context.intent, editEventMode: nil, label: label)]
            return ToolResult(
                intent: context.intent,
                action: ToolAction.info(message: "Proceeding with single option"),
                needsDisambiguation: false,
                options: options,
                message: "Processing your request...",
                richText: nil
            )
        }

        let options = intentAmbiguity.predictions.map { prediction in
            let label = createLabelForIntent(prediction.intent, confidence: prediction.confidence, context: context)
            return ChatMessageActionAlternative(id: prediction.id, parseResultId: context.id, intentOption: prediction.intent, editEventMode: nil, label: label)
        }

        let message = createDisambiguationText(context: context)

        return ToolResult(
            intent: .unknown,
            action: ToolAction.info(message: "Please choose what you'd like to do"),
            needsDisambiguation: true,
            options: options,
            message: message,
            richText: nil
        )
    }

    private func createDisambiguationText(context: CommandContext) -> String {
        var message = "I found multiple ways to interpret your request".localized
        if !context.title.isEmpty {
            message += " for \"\(context.title)\"".localized
        }
        message += ". Please choose what you'd like to do:".localized
        return message
    }

    private func createContextLabel(context: CommandContext) -> AttributedString {
        return createLabelForIntent(context.intent, confidence: 1.0, context: context)
    }

    private func createLabelForIntent(_ intent: Intent, confidence: Float, context: CommandContext) -> AttributedString {
        var attributedLabel = AttributedString()

        var intentText = AttributedString(intent.localizedDescription)
        intentText.font = AppFontStyle.body.weight(.bold).uiFont()
        intentText.foregroundColor = UIColor(Color.theme.text)
        attributedLabel += intentText

        if !context.title.isEmpty {
            var separator = AttributedString(": ")
            intentText.font = AppFontStyle.body.weight(.semibold).uiFont()
            separator.foregroundColor = UIColor(Color.theme.secondaryText)
            attributedLabel += separator

            var titleText = AttributedString("\"\(context.title)\"\n")
            titleText.font = AppFontStyle.body.weight(.semibold).italic().uiFont()
            titleText.foregroundColor = UIColor(Color.theme.text)
            attributedLabel += titleText
        }

        if context.temporalContext.finalDate != .distantPast {
            let dateStr = context.temporalContext.finalDate.formattedDate(
                dateFormat: .long,
                calendar: calendar,
                timeZone: calendar.timeZone
            )

            var dateText = AttributedString(dateStr)
            dateText.font = AppFontStyle.caption.uiFont()
            dateText.foregroundColor = UIColor(Color.theme.secondaryText)
            attributedLabel += dateText
        }

        if EnvConfig.shared.environment == .dev && confidence < 1.0 {
            let percentageConfidence = Int(confidence * 100)
            var confidenceText = AttributedString(" (\(percentageConfidence)%)")
            confidenceText.font = AppFontStyle.caption.weight(.medium).uiFont()
            confidenceText.foregroundColor = .orange
            attributedLabel += confidenceText
        }

        return attributedLabel
    }
}
