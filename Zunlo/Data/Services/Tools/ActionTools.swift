//
//  ActionTools.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/10/25.
//

import Foundation
import SmartParseKit

// MARK: - Tool Result primitives

extension DateInterval {
    func toDateRange() -> Range<Date> {
        let exclusiveEnd = Calendar.current.date(byAdding: .minute, value: 1, to: self.end) ?? self.end
        return self.start..<exclusiveEnd
    }
}

public enum ToolAction: Equatable {
    case createdTask(id: UUID)
    case createdEvent(id: UUID)
    case updatedTask(id: UUID)
    case updatedEvent(id: UUID)
    
    
    // Targeting / selection hints
    case targetTask(id: UUID)
    case targetEventSeries(id: UUID)
    case targetEventOccurrence(eventId: UUID, start: Date)
    case targetEventOverride(id: UUID)
    
    
    // Reschedule intents (explicit new timing + scope so the VM can apply if needed)
    case rescheduledTask(id: UUID, due: Date)
    case rescheduledEvent(eventId: UUID, start: Date, end: Date, scope: EventScope)
    
    
    case plannedDay(range: Range<Date>, occurrences: [EventOccurrence])
    case plannedWeek(range: Range<Date>, occurrences: [EventOccurrence])
    case agenda(range: Range<Date>, occurrences: [EventOccurrence])
    case info(message: String)
    case none
}

public enum EventScope: String, Equatable { case single, all, thisAndFuture, override }

public struct DisambiguationOption: Identifiable, Equatable {
    public let id: UUID
    public let label: String
    public let payload: Payload
    
    
    public enum Payload: Equatable {
        case resolution(ResolutionAlternative)
        case date(Date)
        case dateRange(Range<Date>)
        case duration(TimeInterval)
        case task(UUID)
        case eventSeries(UUID)
        case eventOccurrence(eventId: UUID, start: Date)
        case eventScope(scope: EventScope, eventId: UUID, start: Date)
    }
    
    
    public init(label: String, payload: Payload) {
        self.id = UUID()
        self.label = label
        self.payload = payload
    }
}

public struct ToolResult: Equatable {
    public let intent: Intent
    public let action: ToolAction
    public let needsDisambiguation: Bool
    public let options: [DisambiguationOption]
    public let message: String?
    public let richText: AttributedString?

    public init(intent: Intent,
                action: ToolAction = .none,
                needsDisambiguation: Bool = false,
                options: [DisambiguationOption] = [],
                message: String? = nil,
                richText: AttributedString? = nil
    ) {
        self.intent = intent
        self.action = action
        self.needsDisambiguation = needsDisambiguation
        self.options = options
        self.message = message
        self.richText = richText
    }
}

public protocol Tools {
    func createTask(_ cmd: ParseResult) async -> ToolResult
    func createEvent(_ cmd: ParseResult) async -> ToolResult
    func rescheduleTask(_ cmd: ParseResult) async -> ToolResult
    func rescheduleEvent(_ cmd: ParseResult) async -> ToolResult
    func updateTask(_ cmd: ParseResult) async -> ToolResult
    func updateEvent(_ cmd: ParseResult) async -> ToolResult
    func planWeek(_ cmd: ParseResult) async -> ToolResult
    func planDay(_ cmd: ParseResult) async -> ToolResult
    func showAgenda(_ cmd: ParseResult) async -> ToolResult
    func moreInfo(_ cmd: ParseResult) async -> ToolResult
    func unknown(_ cmd: ParseResult) async -> ToolResult
}

// MARK: - ActionTools

/// `ActionTools` is a lean executor that takes a parsed command and tries to
/// perform it end-to-end. When information is insufficient or ambiguous,
/// it returns a `ToolResult` with `needsDisambiguation = true` and options
/// so the ViewModel can show a disambiguation bubble in chat.
final class ActionTools: Tools {
    private let events: EventStore
    private let tasks: TaskStore
    private var calendar: Calendar

    init(events: EventStore, tasks: TaskStore, calendar: Calendar = .appDefault) {
        self.calendar = calendar
        self.events = events
        self.tasks = tasks
    }

    // MARK: Tools conformance

    public func planWeek(_ cmd: ParseResult) async -> ToolResult {
        let dateInterval = cmd.context.dateRange
        guard let range = dateInterval?.toDateRange() else {
            return ToolResult(intent: cmd.intent, action: .info(message: "Plan request with no period"), needsDisambiguation: true)
        }
        do {
            let occ = try await events.fetchOccurrences(in: range)
            return ToolResult(intent: cmd.intent, action: .plannedWeek(range: range, occurrences: occ), message: NSLocalizedString("Here is your week.", comment: ""))
        } catch {
            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: false, options: [], message: error.localizedDescription)
        }
    }

    public func planDay(_ cmd: ParseResult) async -> ToolResult {
        let dateInterval = cmd.context.dateRange
        guard let range = dateInterval?.toDateRange() else {
            return ToolResult(intent: cmd.intent, action: .info(message: "Plan request with no period"), needsDisambiguation: true)
        }
        do {
            let occ = try await events.fetchOccurrences(in: range)
            return ToolResult(intent: cmd.intent, action: .plannedDay(range: range, occurrences: occ), message: NSLocalizedString("Here is your day.", comment: ""))
        } catch {
            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: false, options: [], message: error.localizedDescription)
        }
    }

    public func showAgenda(_ cmd: ParseResult) async -> ToolResult {
        let dateInterval = cmd.context.dateRange
        guard let range = dateInterval?.toDateRange() else {
            return ToolResult(intent: cmd.intent, action: .info(message: "Agenda request with no period"), needsDisambiguation: true)
        }
        do {
            let occ = try await events.fetchOccurrences(in: range)
            return ToolResult(intent: cmd.intent, action: .agenda(range: range, occurrences: occ), message: NSLocalizedString("Agenda ready.", comment: ""))
        } catch {
            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: false, options: [], message: error.localizedDescription)
        }
    }
    
    public func createTask(_ cmd: ParseResult) async -> ToolResult {
        let title = cmd.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return ToolResult(
                intent: cmd.intent,
                action: .none,
                needsDisambiguation: true,
                options: [],
                message: NSLocalizedString("I need a task title.", comment: "")
            )
        }

        // Prefer explicit `when`; otherwise offer alternatives as due-date options.
        let when = cmd.context.finalDate
        do {
            let id = try await tasks.insert(title: title, due: when)
            return ToolResult(intent: cmd.intent, action: .createdTask(id: id), message: ok("task", title, when))
        } catch {
            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: false, options: [], message: error.localizedDescription)
        }

        // If the parser produced alternatives with dates, surface them as choices.
//        let options = cmd.alternatives.map { alt in
//            DisambiguationOption(label: alt.label ?? formatDate(alt.date), payload: .resolution(alt))
//        }
//        if !options.isEmpty {
//            return ToolResult(
//                intent: cmd.intent,
//                action: .none,
//                needsDisambiguation: true,
//                options: options,
//                message: NSLocalizedString("Pick a due date for ‘%@’.", comment: "disambig message").replacingOccurrences(of: "%@", with: title)
//            )
//        }

        // No date information at all — create an undated task (if your model supports that)
//        do {
//            let id = try await tasks.insert(title: title, due: nil)
//            return ToolResult(intent: cmd.intent, action: .createdTask(id: id), message: ok("task", title, nil))
//        } catch {
//            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: false, options: [], message: error.localizedDescription)
//        }
    }

    public func createEvent(_ cmd: ParseResult) async -> ToolResult {
        let title = cmd.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: true, options: [], message: NSLocalizedString("I need an event title.", comment: ""))
        }

        // Determine start/end
        let start: Date = cmd.context.finalDate
        var end: Date? = cmd.context.finalDateDuration == nil ? nil : start.addingTimeInterval(cmd.context.finalDateDuration!)

        // If we only have a start, infer a default duration (60m) or from alternative
        if end == nil {
            end = calendar.date(byAdding: .second, value: 60 * 60, to: start)
        }
//        else {
//            // Missing time entirely → disambiguation using alternatives
//            let opts = cmd.alternatives.map { alt in
//                DisambiguationOption(label: alt.label ?? labelFor(alt), payload: .resolution(alt))
//            }
//            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: true, options: opts, message: NSLocalizedString("What time should ‘%@’ be?", comment: "").replacingOccurrences(of: "%@", with: title))
//        }

        let s = start
        guard let e = end, s < e else {
            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: true, options: [], message: NSLocalizedString("I need a valid start and end time.", comment: ""))
        }

        // Build and save
        guard let ev = events.makeEvent(title: title, start: s, end: e) else {
            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: false, options: [], message: NSLocalizedString("Could not prepare the event.", comment: ""))
        }
        do {
            try await events.upsert(ev)
            return ToolResult(intent: cmd.intent, action: .createdEvent(id: ev.id), message: ok("event", title, s, e))
        } catch {
            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: false, options: [], message: error.localizedDescription)
        }
    }

    public func updateTask(_ cmd: ParseResult) async -> ToolResult {
        // Fetch candidates via store and score them by title/time proximity
        do {
            let candidates = try await tasks.fetchAll().compactMap { TaskCandidate(id: $0.id, title: $0.title, due: $0.dueDate) }
            let scored = bestTaskCandidates(in: candidates, cmd: cmd)
            let (single, many) = pick(scored)
            if let one = single {
                return ToolResult(intent: cmd.intent,
                                   action: .targetTask(id: one.id),
                                   needsDisambiguation: false,
                                   options: [],
                                   message: NSLocalizedString("Updating ‘%@’.", comment: "").replacingOccurrences(of: "%@", with: one.title))
            }
            if !many.isEmpty {
                let opts = many.map { t in
                    DisambiguationOption(label: taskLabel(t), payload: .task(t.id))
                }
                return ToolResult(intent: cmd.intent,
                                  action: .none,
                                  needsDisambiguation: true,
                                  options: opts,
                                  message: NSLocalizedString("Which task should I update?", comment: ""))
            }
            // No good matches — fall back to asking
            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: true, options: [], message: NSLocalizedString("I couldn't find a matching task.", comment: ""))
        } catch {
            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: false, options: [], message: error.localizedDescription)
        }
    }
    
    // NEW: Update Event (non-time edits only)
    public func updateEvent(_ cmd: ParseResult) async -> ToolResult {
        // Only non-time fields (currently: title). If nothing to change, bail early.
        let hasTitleChange = (cmd.title.isEmpty == false)
        guard hasTitleChange else {
            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: false, options: [], message: NSLocalizedString("No non-time changes detected.", comment: ""))
        }

        do {
            let range = searchRange(for: cmd)
            let occ = try await events.fetchOccurrences(in: range)
            let scored = bestEventCandidates(in: occ, cmd: cmd, titleBias: 0.9)
            let (single, many) = pick(scored, threshold: 0.70)

            guard let one = single else {
                if !many.isEmpty {
                    let opts = many.map { e in DisambiguationOption(label: eventLabel(e), payload: .eventOccurrence(eventId: e.id, start: e.startDate)) }
                    return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: true, options: opts, message: NSLocalizedString("Which event do you want to update?", comment: ""))
                }
                return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: true, options: [], message: NSLocalizedString("I couldn't find a matching event.", comment: ""))
            }

            let newTitle = cmd.title
            let input = buildEditInput(from: one, newStart: one.startDate, newEnd: one.endDate, newTitle: newTitle)

            // Scope handling for non-time edits: be conservative.
            if one.isOverride {
                if let ov = one.overrides.first(where: { calendar.isDate($0.occurrenceDate, inSameDayAs: one.startDate) }) {
                    try await events.editOverride(ov, with: input)
                    return ToolResult(intent: cmd.intent, action: .updatedEvent(id: one.id), needsDisambiguation: false, options: [], message: NSLocalizedString("Updated this override.", comment: ""))
                }
            }

            if one.isRecurring {
                // Ask for scope (this occurrence / this & future / all)
                let opts = buildScopeOptions(for: one)
                return ToolResult(intent: cmd.intent, action: .targetEventOccurrence(eventId: one.id, start: one.startDate), needsDisambiguation: true, options: opts, message: NSLocalizedString("Apply title change to:", comment: ""))
            } else {
                // Non-recurring → editAll is effectively the single event.
                try await events.editAll(event: one, with: input, oldRule: nil)
                return ToolResult(intent: cmd.intent, action: .updatedEvent(id: one.id), needsDisambiguation: false, options: [], message: NSLocalizedString("Updated the event.", comment: ""))
            }
        } catch {
            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: false, options: [], message: error.localizedDescription)
        }
    }
    
    // NEW: Reschedule Task
    public func rescheduleTask(_ cmd: ParseResult) async -> ToolResult {
        do {
            let candidates = try await tasks.fetchAll().compactMap { TaskCandidate(id: $0.id, title: $0.title, due: $0.dueDate) }
            let scored = bestTaskCandidates(in: candidates, cmd: cmd)
            let (single, many) = pick(scored)

            // Need a target
            guard let one = single else {
                if !many.isEmpty {
                    let opts = many.map { t in DisambiguationOption(label: taskLabel(t), payload: .task(t.id)) }
                    return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: true, options: opts, message: NSLocalizedString("Which task should I reschedule?", comment: ""))
                }
                return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: true, options: buildTimeOptions(from: cmd), message: NSLocalizedString("I couldn't find a matching task.", comment: ""))
            }

            // Need a new due time
            guard let newDue = deriveNewDue(from: cmd) else {
                let timeOpts = buildTimeOptions(from: cmd)
                return ToolResult(intent: cmd.intent, action: .targetTask(id: one.id), needsDisambiguation: true, options: timeOpts, message: NSLocalizedString("Pick a new time for ‘%@’.", comment: "").replacingOccurrences(of: "%@", with: one.title))
            }

            // Try to apply automatically; if the adapter isn't wired yet, we'll still return the proposed action.
            do {
                try await tasks.update(id: one.id, due: newDue)
                return ToolResult(intent: cmd.intent, action: .rescheduledTask(id: one.id, due: newDue), needsDisambiguation: false, options: [], message: String(format: NSLocalizedString("Rescheduled ‘%@’ to %@.", comment: ""), one.title, formatDate(newDue)))
            } catch {
                // Fall back to returning the plan without applying
                return ToolResult(intent: cmd.intent, action: .rescheduledTask(id: one.id, due: newDue), needsDisambiguation: false, options: [], message: String(format: NSLocalizedString("Will reschedule ‘%@’ to %@ (apply failed: %@).", comment: ""), one.title, formatDate(newDue), error.localizedDescription))
            }
        } catch {
            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: false, options: [], message: error.localizedDescription)
        }
    }

    // NEW: Reschedule Event (time edits with scope inference)
    public func rescheduleEvent(_ cmd: ParseResult) async -> ToolResult {
        do {
            let range = searchRange(for: cmd)
            let occ = try await events.fetchOccurrences()
            let scored = bestEventCandidates(in: occ, cmd: cmd, titleBias: 0.75)
            let (single, many) = pick(scored, threshold: 0.7)

            guard let one = single else {
                if !many.isEmpty {
                    let opts = many.map { e in DisambiguationOption(label: eventLabel(e), payload: .eventOccurrence(eventId: e.id, start: e.startDate)) }
                    return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: true, options: opts, message: NSLocalizedString("Which event should I reschedule?", comment: ""))
                }
                return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: true, options: buildTimeOptions(from: cmd), message: NSLocalizedString("I couldn't find a matching event.", comment: ""))
            }

            // Determine new start/end
            guard let (newStart, newEnd) = timingFrom(cmd, current: one) else {
                let timeOpts = buildTimeOptions(from: cmd)
                return ToolResult(intent: cmd.intent, action: .targetEventOccurrence(eventId: one.id, start: one.startDate), needsDisambiguation: true, options: timeOpts, message: NSLocalizedString("Pick a new time for this event.", comment: ""))
            }

            // Infer scope
            let scope = inferEventScope(for: one, newStart: newStart)
            let input = buildEditInput(from: one, newStart: newStart, newEnd: newEnd)

            // Apply
            switch scope {
            case .override:
                if let ov = one.overrides.first(where: { calendar.isDate($0.occurrenceDate, inSameDayAs: one.startDate) }) {
                    try await events.editOverride(ov, with: input)
                } else {
                    // No explicit override present; treat as single
                    fallthrough
                }
            case .single:
                if let parent = try await fetchParentOccurrence(for: one) {
                    try await events.editSingle(parent: parent, occurrence: one, with: input)
                } else {
                    // Fallback: editAll as a last resort when we can't find parent info
                    try await events.editAll(event: one, with: input, oldRule: one.recurrence_rules.first)
                }
            case .thisAndFuture:
                if let parent = try await fetchParentOccurrence(for: one) {
                    try await events.editFuture(parent: parent, startingFrom: one, with: input)
                } else {
                    // Without parent we cannot split reliably; ask user
                    let opts = buildScopeOptions(for: one)
                    return ToolResult(intent: cmd.intent, action: .targetEventOccurrence(eventId: one.id, start: one.startDate), needsDisambiguation: true, options: opts, message: NSLocalizedString("Do you want to update just this one or the whole series?", comment: ""))
                }
            case .all:
                try await events.editAll(event: one, with: input, oldRule: one.recurrence_rules.first)
            }

            return ToolResult(intent: cmd.intent, action: .rescheduledEvent(eventId: one.id, start: newStart, end: newEnd, scope: scope), needsDisambiguation: false, options: [], message: String(format: NSLocalizedString("Rescheduled ‘%@’.", comment: ""), one.title))
        } catch {
            return ToolResult(intent: cmd.intent, action: .none, needsDisambiguation: false, options: [], message: error.localizedDescription)
        }
    }
    
    public func moreInfo(_ cmd: ParseResult) async -> ToolResult {
        let summary = describe(cmd)
        let opts = buildTimeOptions(from: cmd)
        return ToolResult(intent: cmd.intent, action: .info(message: summary), needsDisambiguation: !opts.isEmpty, options: opts, message: summary)
    }

    public func unknown(_ cmd: ParseResult) async -> ToolResult {
        ToolResult(intent: .unknown, action: .none, needsDisambiguation: true, options: buildTimeOptions(from: cmd), message: NSLocalizedString("I couldn't figure that out. Did you mean to create a task or an event?", comment: ""))
    }
}

// MARK: - Helpers


private extension ActionTools {
    struct Scored<T> { let value: T; let score: Double }

    func normalize(_ s: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        return s.lowercased()
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
    }

    func titleScore(_ a: String?, _ b: String?) -> Double {
        guard let a = a?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty,
              let b = b?.trimmingCharacters(in: .whitespacesAndNewlines), !b.isEmpty else { return 0 }
        let ta = Set(normalize(a)); let tb = Set(normalize(b))
        if ta.isEmpty || tb.isEmpty { return 0 }
        let inter = ta.intersection(tb).count
        let denom = ta.count + tb.count
        return denom > 0 ? (Double(2 * inter) / Double(denom)) : 0
    }

    func timeScore(target: Date?, anchor: Date?, toleranceHours: Double = 6) -> Double {
        guard let t = target, let a = anchor else { return 0 }
        let delta = abs(t.timeIntervalSince(a)) / 3600.0 // hours
        // 1.0 at zero, decays with distance; ~0.5 at tolerance, then quickly drops
        let k = max(0, 1 - (delta / (toleranceHours * 2)))
        return min(1, max(0, 1 - (delta / max(0.1, toleranceHours)))) * 0.7 + k * 0.3
    }

    func combine(_ title: Double, _ time: Double, titleWeight: Double = 0.65) -> Double {
        return titleWeight * title + (1 - titleWeight) * time
    }

    func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }

    func formatRange(_ start: Date, _ end: Date) -> String {
        let df = DateIntervalFormatter()
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: start, to: end)
    }

    func ok(_ kind: String, _ title: String, _ start: Date?, _ end: Date? = nil) -> String {
        if let s = start, let e = end {
            return String(format: NSLocalizedString("Created %@ ‘%@’ from %@ to %@.", comment: ""), kind, title, formatDate(s), formatDate(e))
        } else if let s = start {
            return String(format: NSLocalizedString("Created %@ ‘%@’ for %@.", comment: ""), kind, title, formatDate(s))
        } else {
            return String(format: NSLocalizedString("Created %@ ‘%@’.", comment: ""), kind, title)
        }
    }

    func labelFor(_ alt: ResolutionAlternative) -> String {
        if let l = alt.label { return l }
        if let d = alt.duration, d > 0 {
            let minutes = Int(d / 60)
            return "\(formatDate(alt.date)) (\(minutes)m)"
        }
        return formatDate(alt.date)
    }

    func buildTimeOptions(from cmd: ParseResult) -> [DisambiguationOption] {
//        cmd.alternatives.map { DisambiguationOption(label: labelFor($0), payload: .resolution($0)) }
        return []
    }

    func dayRange(containing date: Date) -> Range<Date> {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return start..<end
    }

    func weekRange(containing date: Date) -> Range<Date> {
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        let end = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
        return startOfWeek..<end
    }

    func describe(_ cmd: ParseResult) -> String {
        var bits: [String] = []
        bits.append("intent=\(cmd.intent.rawValue)")
        bits.append("title=\(cmd.title)")
        bits.append("when=\(formatDate(cmd.context.finalDate))")
        if let d = cmd.context.finalDateDuration { bits.append("duration=\(d)") }
        if let r = cmd.context.dateRange { bits.append("range=\(formatDate(r.start))–\(formatDate(r.end))") }
//        bits.append("alts=\(cmd.alternatives.count)")
        return bits.joined(separator: ", ")
    }

    // MARK: Smart matching

    func searchRange(for cmd: ParseResult, defaultHours: Int = 12) -> Range<Date> {
        if let r = cmd.context.dateRange { return r.toDateRange() }
        return dayRange(containing: Date())
    }

    func eventLabel(_ occ: EventOccurrence) -> String {
        let title = (!occ.title.isEmpty ? occ.title : NSLocalizedString("(no title)", comment: ""))
        return "\(title) — \(formatRange(occ.startDate, occ.endDate))"
    }

    struct TaskCandidate: Identifiable, Equatable { public let id: UUID; public let title: String; public let due: Date? }

    func taskLabel(_ t: TaskCandidate) -> String {
        if let due = t.due { return "\(t.title) — \(formatDate(due))" }
        return t.title
    }

    func bestEventCandidates(in occs: [EventOccurrence], cmd: ParseResult, top: Int = 5, titleBias: Double = 0.65) -> [Scored<EventOccurrence>] {
        let anch = cmd.context.dateRange?.start ?? cmd.context.finalDate
        let q = cmd.title
        let scored = occs.map { occ -> Scored<EventOccurrence> in
            let ts = titleScore(q, occ.title)
            let times = timeScore(target: occ.startDate, anchor: anch)
            let s = combine(ts, times, titleWeight: titleBias)
            return Scored(value: occ, score: s)
        }
        return scored.sorted { $0.score > $1.score }.prefix(top).map { $0 }
    }

    func bestTaskCandidates(in tasks: [TaskCandidate], cmd: ParseResult, top: Int = 5, titleBias: Double = 0.75) -> [Scored<TaskCandidate>] {
        let anch = cmd.context.dateRange?.start ?? cmd.context.finalDate
        let q = cmd.title
        let scored = tasks.map { t -> Scored<TaskCandidate> in
            let ts = titleScore(q, t.title)
            let times = timeScore(target: t.due, anchor: anch)
            let s = combine(ts, times, titleWeight: titleBias)
            return Scored(value: t, score: s)
        }
        return scored.sorted { $0.score > $1.score }.prefix(top).map { $0 }
    }

    func pick<T>(_ scored: [Scored<T>], threshold: Double = 0.72) -> (single: T?, many: [T]) {
        guard let first = scored.first else { return (nil, []) }
        let strong = scored.filter { $0.score >= threshold }
        if strong.count == 1 { return (single: first.value, many: []) }
        return (single: nil, many: strong.map { $0.value })
    }

    // MARK: Timing derivation & scope inference

    func deriveNewDue(from cmd: ParseResult) -> Date? {
        if let r = cmd.context.dateRange { return r.start }
        return cmd.context.finalDate
    }

    func timingFrom(_ cmd: ParseResult, current: EventOccurrence) -> (Date, Date)? {
        if let r = cmd.context.dateRange { return (r.start, r.end) }
        let w = cmd.context.finalDate
        if let d = cmd.context.finalDateDuration { return (w, w.addingTimeInterval(d)) }
        return nil
    }

    func inferEventScope(for occ: EventOccurrence, newStart: Date) -> EventScope {
        if occ.isOverride { return .override }
        if !occ.isRecurring { return .all }
        // If same day move, treat as a single occurrence tweak
        if calendar.isDate(newStart, inSameDayAs: occ.startDate) { return .single }
        // If moving forward beyond the day, prefer this-and-future (safe split)
        if newStart > occ.startDate.addingTimeInterval(24*3600) { return .thisAndFuture }
        // Otherwise default to single edit to be least destructive
        return .single
    }

    func buildEditInput(from occ: EventOccurrence, newStart: Date, newEnd: Date, newTitle: String? = nil, newLocation: String? = nil) -> EditEventInput {
        let rule = occ.recurrence_rules.first
        return EditEventInput(
            id: occ.id,
            userId: occ.userId,
            title: newTitle ?? occ.title,
            notes: occ.notes,
            startDate: newStart,
            endDate: newEnd,
            isRecurring: occ.isRecurring,
            location: newLocation ?? occ.location,
            color: occ.color,
            reminderTriggers: occ.reminderTriggers,
            recurrenceType: rule.map { $0.freq.rawValue },
            recurrenceInterval: rule?.interval,
            byWeekday: rule?.byWeekday,
            byMonthday: rule?.byMonthday,
            until: rule?.until,
            count: rule?.count,
            isCancelled: occ.isCancelled
        )
    }

    func buildScopeOptions(for occ: EventOccurrence) -> [DisambiguationOption] {
        var opts: [DisambiguationOption] = []
        opts.append(DisambiguationOption(label: NSLocalizedString("This occurrence", comment: ""), payload: .eventScope(scope: .single, eventId: occ.id, start: occ.startDate)))
        if occ.isRecurring {
            opts.append(DisambiguationOption(label: NSLocalizedString("This and future", comment: ""), payload: .eventScope(scope: .thisAndFuture, eventId: occ.id, start: occ.startDate)))
            opts.append(DisambiguationOption(label: NSLocalizedString("All in series", comment: ""), payload: .eventScope(scope: .all, eventId: occ.id, start: occ.startDate)))
        }
        return opts
    }

    func fetchParentOccurrence(for occ: EventOccurrence) async throws -> EventOccurrence? {
        // Try to resolve the parent using the underlying eventId if the store supports it
        if let parent = try? await events.fetchOccurrences(id: occ.eventId) { return parent }
        return nil
    }
}
