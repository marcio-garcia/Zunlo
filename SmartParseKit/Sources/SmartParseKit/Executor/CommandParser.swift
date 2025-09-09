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

        // 1) Language + intent
        let language = engine.detectLanguage(raw)
        let intent = engine.classify(raw)

        // 2) Build a calendar localized to the detected language
        var cal = calendar
        cal.locale = Locale(identifier: language.rawValue)

        let packs: [DateLanguagePack] = [
            PortugueseBRPack(calendar: cal),
            EnglishPack(calendar: cal)
        ]
        
        // 3) Date detection (use the *localized* calendar everywhere)
        let dateDetector = HumanDateDetector(
            calendar: cal,
            policy: RelativeWeekdayPolicy(this: .upcomingExcludingToday, next: .immediateUpcoming),
            packs: packs
        )
        let resolutions = dateDetector.normalizedResolutions(in: raw, base: now)

        // If any ambiguous → steer to moreInfo (or keep intent and attach a prompt)
        if let ambiguous = resolutions.first(where: { $0.ambiguous }) {
            return ParsedCommand(
                intent: .moreInfo,
                title: extractTitle(ambiguous.text),
                when: nil,
                end: nil,
                dateRange: nil,
                newTime: nil,
                language: language,
                raw: raw,
                alternatives: ambiguous.alternatives
            )
        }
        
        // Convenience accessors
        let first = resolutions.first
        let last  = resolutions.last

        // 4) Primary “when”
        let when: Date? = first?.resolvedDate

        // 5) “end”: if there are 2+ date mentions, second one is a natural end or target time
        let end: Date? = resolutions.count >= 2 ? resolutions[1].resolvedDate : nil

        // 6) dateRange (respect synthesized durations first, then infer)
        var dateRange: Range<Date>? = nil
        if let start = when {
            if let dur = first?.duration, dur > 0 {
                // e.g. “this week/next week” synthesized by HumanDateDetector
                dateRange = start..<start.addingTimeInterval(dur)
            } else if let endDate = end {
                // Two points → treat as range
                dateRange = min(start, endDate)..<max(start, endDate)
            } else {
                dateRange = start..<start.addingTimeInterval(60 * 60)
            }
        }

        // 7) Intent-specific overrides / fallbacks
        switch intent {
        case .planDay:
            // If we don’t already have a solid range, default to today
            if dateRange == nil {
                let start = cal.startOfDay(for: now)
                let end = cal.date(byAdding: .day, value: 1, to: start)!
                dateRange = start..<end
            }

        case .planWeek:
            // Prefer synthesized week ranges; otherwise compute from modifier
            if dateRange == nil {
                if let r = first {
                    if r.isWeekPhrase {
                        // If the detector gave no duration for some reason, compute via calendar
                        if let dur = r.duration, dur > 0 {
                            dateRange = r.resolvedDate..<r.resolvedDate.addingTimeInterval(dur)
                        } else {
                            dateRange = (r.modifier == .next)
                                ? nextWeekRange(from: now, calendar: cal)
                                : weekRange(containing: now, calendar: cal)
                        }
                    } else {
                        // Not a week phrase but planWeek intent (e.g., “plan my next week” missed):
                        // fall back to next/this week based on modifier if present
                        switch r.modifier {
                        case .next: dateRange = nextWeekRange(from: now, calendar: cal)
                        case .this, .none: dateRange = weekRange(containing: now, calendar: cal)
                        }
                    }
                } else {
                    // No dates detected at all → default to this week
                    dateRange = weekRange(containing: now, calendar: cal)
                }
            }

        case .showAgenda:
            if dateRange == nil {
                // If it’s a synthesized week phrase, build the week range
                if let r = first, r.isWeekPhrase {
                    if let dur = r.duration, dur > 0 {
                        dateRange = r.resolvedDate..<r.resolvedDate.addingTimeInterval(dur)
                    } else {
                        dateRange = (r.modifier == .next)
                            ? nextWeekRange(from: now, calendar: cal)
                            : weekRange(containing: now, calendar: cal)
                    }
                } else if let start = when {
                    // Single day agenda (“agenda for Sunday”)
                    let d0 = cal.startOfDay(for: start)
                    let d1 = cal.date(byAdding: .day, value: 1, to: d0)!
                    dateRange = d0..<d1
                } else if resolutions.count >= 2, let s = first?.resolvedDate, let e = last?.resolvedDate {
                    dateRange = min(s, e)..<max(s, e)
                }
            }

        default:
            break
        }

        // 8) newTime (destination time), for updates
        var newTime: Date? = nil
        if intent == .updateEvent || intent == .rescheduleEvent || intent == .rescheduleTask {
            // Usually the last mentioned time is the target
            newTime = last?.resolvedDate ?? when
        }

        // 9) Title
        let title = extractTitle(raw)

        return ParsedCommand(
            intent: intent,
            title: title,
            when: when,
            end: end,
            dateRange: dateRange,
            newTime: newTime,
            language: language,
            raw: raw,
            alternatives: []
        )
    }

}
