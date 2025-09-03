//
//  CommandParser.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

import Foundation
import NaturalLanguage

// IntentEngine → classifies raw text into a high-level label (create_event, reschedule_task, plan_week, etc.).
// CommandParser → runs regex / NSDataDetector / NLTagger passes to extract structured entities:
//  {when} → “tomorrow”, “Friday 2pm”, “next week”
//  {time} → “14:00”, “9:30”
//  {task} / {obj} → “buy cat food”, “team meeting”, “call Ana”
//  other metadata like {title}, {location}, {tags}
// Mapper → fills your Event or UserTask model fields (title, startDate, notes, etc.) based on the entities.

public final class CommandParser {
    private let engine: IntentEngine
    
    public init(engine: IntentEngine = IntentEngine()) {
        self.engine = engine
    }
    
    public func parse(_ raw: String, now: Date = Date(), calendar: Calendar = .current) -> ParsedCommand {
        let language = engine.detectLanguage(raw)
        let intent = engine.classify(raw)
        
        // Dates & ranges
        let dateResult = extractDates(raw, locale: Locale(identifier: language.rawValue))
        let when: Date? = dateResult.dates.first
        var end: Date?
        var dateRange: Range<Date>?
        
        if let stat = when {
            dateRange = stat..<stat.addingTimeInterval(dateResult.duration)
        }
        
        if dateResult.dates.count >= 2 {
            end = dateResult.dates[1]
        }
        
        // Week phrases
        let lower = raw.lowercased()
        if dateRange == nil {
            if lower.contains("this week") || lower.contains("esta semana") || lower.contains("essa semana") {
                dateRange = weekRange(containing: now, calendar: calendar)
            } else if lower.contains("next week") || lower.contains("próxima semana") {
                dateRange = nextWeekRange(from: now, calendar: calendar)
            }
        }
        
        // Reschedule destination time (usually the last time mentioned)
        var newTime: Date?
        if intent == .rescheduleEvent {
            newTime = dateResult.dates.last ?? when
        }
        
        let title = extractTitle(raw)
        
        return ParsedCommand(
            intent: intent,
            title: title,
            when: when,
            end: end,
            dateRange: dateRange,
            newTime: newTime,
            language: language,
            raw: raw
        )
    }
}
