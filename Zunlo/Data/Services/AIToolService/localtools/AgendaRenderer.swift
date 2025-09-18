//
//  AgendaRenderer.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/20/25.
//

import Foundation
import GlowUI

public struct AgendaRenderParts {
    public let attributed: AttributedString
    public let text: String
    public let json: String
    public let schema: String
}

public struct AgendaRenderer {
    public static func renderParts(
        _ agenda: GetAgendaResult,
        agendaRange: GetAgendaArgs.DateRange,
        schema: String = "zunlo.agenda#1",
        timeZone: TimeZone
    ) -> AgendaRenderParts {
        let tz = timeZone
        let f = Formatters(timeZone: tz)

        // Split items
        let events: [AgendaEvent] = agenda.items.compactMap { if case let .event(e) = $0 { e } else { nil } }
            .sorted { $0.start < $1.start }
        let tasks:  [AgendaTask]  = agenda.items.compactMap { if case let .task(t)  = $0 { t } else { nil } }
            .sorted {
                switch ($0.dueDate, $1.dueDate) {
                case let (a?, b?): return a < b
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
            }

        // -------- Styles
        var hdr  = AttributeContainer(); hdr.font  = AppFontStyle.subtitle.uiFont() // .system(.title3, design: .rounded).weight(.semibold)
        var sec  = AttributeContainer(); sec.font  = AppFontStyle.heading.uiFont() // .system(.headline, design: .rounded)
        var time = AttributeContainer(); time.font = AppFontStyle.body.uiFont() // .system(.subheadline); time.foregroundColor = .secondary
        var ttl  = AttributeContainer(); ttl.font  = AppFontStyle.body.weight(.bold).uiFont() // .system(.body).weight(.semibold)
        var meta = AttributeContainer(); meta.font = AppFontStyle.callout.uiFont() // .system(.footnote);   meta.foregroundColor = .secondary

        // Helper
        @inline(__always)
        func line(_ s: String, style: AttributeContainer? = nil) -> AttributedString {
            var a = AttributedString(s + "\n")
            if let style { a.setAttributes(style) }
            return a
        }

        // Period label
        var period = agendaRange.rawValue
        if case .custom = agendaRange {
            period = "\(f.humanDate.string(from: agenda.start)) → \(f.humanDate.string(from: agenda.end))"
        }

        // -------- Build attributed output
        var out = AttributedString()
        out += line("Agenda — \(period)", style: hdr)
        out += line("")

        if !events.isEmpty {
            out += line("Events", style: sec)
            out += line("")
            for (i, e) in events.enumerated() {
                let idx = i + 1
                let timeRange = f.timeRange(from: e.start, to: e.end, includeDay: agendaRange == .custom)

                let num = AttributedString("\(idx). ")
                // number inherits body; leave as default

                var t = AttributedString(timeRange)
                t.setAttributes(time)

                let sep = AttributedString(" — ")

                var title = AttributedString(e.title)
                title.setAttributes(ttl)

                out += num + t + sep + title
                out += line("")

                // meta line (location, flags)
                var metaBits: [String] = []
                if let loc = e.location, !loc.isEmpty { metaBits.append("@ \(loc)") }
                // add flags if you have any
                if !metaBits.isEmpty {
                    var m = AttributedString("   • " + metaBits.joined(separator: "  • "))
                    m.setAttributes(meta)
                    out += m
                    out += line("")
                }

                out += line("") // extra spacing between items
            }
        }

        if !tasks.isEmpty {
            out += line("Tasks", style: sec)
            out += line("")
            for (i, tsk) in tasks.enumerated() {
                let idx = i + 1
                let dueStr = tsk.dueDate.map { f.humanDate.string(from: $0) } ?? "no due date"

                let num = AttributedString("\(idx). ")
                var pri = AttributedString("(\(tsk.priority)) ")
                pri.setAttributes(time)

                var title = AttributedString(tsk.title)
                title.setAttributes(ttl)

                var due = AttributedString("   • due \(dueStr)")
                due.setAttributes(meta)

                out += num + pri + title
                out += line("")
                out += due
                out += line("") + line("")
            }
        }

        if events.isEmpty && tasks.isEmpty {
            var empty = AttributedString("No items in this range.")
            var emptyStyle = AttributeContainer()
            emptyStyle.font = AppFontStyle.body.uiFont() // .system(.body)
            emptyStyle.foregroundColor = .secondary
            empty.setAttributes(emptyStyle)
            out += empty
            out += line("")
        }

        // (Optional) Plain text fallback, if you still want to keep/share it:
        let textFallback = String(out.characters)

        // ---- Build JSON (unchanged)
        struct Payload: Encodable {
            let schema: String
            let timezone: String
            let start: String
            let end: String
            let items: [AgendaItem]
        }
        let utcISO = ISO8601DateFormatter()
        utcISO.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        utcISO.timeZone = TimeZone(secondsFromGMT: 0)

        let payload = Payload(
            schema: schema,
            timezone: tz.identifier,
            start: utcISO.string(from: agenda.start),
            end: utcISO.string(from: agenda.end),
            items: agenda.items
        )

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .custom { (date, encoder) in
            var c = encoder.singleValueContainer()
            try c.encode(utcISO.string(from: date))
        }
        let jsonOut = (try? String(data: enc.encode(payload), encoding: .utf8)) ?? "{}"

        return AgendaRenderParts(attributed: out, text: textFallback, json: jsonOut, schema: schema)
    }
    
    public static func renderWeekParts(
        _ agenda: GetAgendaResult,
        schema: String = "zunlo.agenda#1",
        calendar: Calendar
    ) -> AgendaRenderParts {
        let f = Formatters(timeZone: calendar.timeZone)

        // -------- Styles (same as renderParts)
        var hdr  = AttributeContainer(); hdr.font  = AppFontStyle.subtitle.uiFont()
        var sec  = AttributeContainer(); sec.font  = AppFontStyle.heading.uiFont()
        var time = AttributeContainer(); time.font = AppFontStyle.body.uiFont()
        var ttl  = AttributeContainer(); ttl.font  = AppFontStyle.body.weight(.bold).uiFont()
        var meta = AttributeContainer(); meta.font = AppFontStyle.callout.uiFont()

        @inline(__always)
        func line(_ s: String, style: AttributeContainer? = nil) -> AttributedString {
            var a = AttributedString(s + "\n")
            if let style { a.setAttributes(style) }
            return a
        }

        // Compute nice "Week of ..." label
        let weekStart = calendar.startOfDay(for: agenda.start)
        let weekEnd   = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: agenda.end)) ?? agenda.end
        let periodLabel = "Week of \(f.humanDate.string(from: weekStart)) – \(f.humanDate.string(from: weekEnd))"

        // Group items
        let (days, undatedTasks) = groupAgendaByDay(agenda, calendar: calendar)

        // Helper: clip event times to the specific day being rendered
        func clippedTimesForEventOnDay(_ e: AgendaEvent, dayStart: Date) -> (Date, Date?) {
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let start = max(e.start, dayStart)
            let endExclusive = (e.end ?? e.start)
            let end = min(endExclusive, dayEnd)
            // If the clipped end collapsed to start, show single time
            return start < end ? (start, end) : (start, nil)
        }

        // -------- Build attributed output
        var out = AttributedString()
        out += line("Agenda — \(periodLabel)", style: hdr)
        out += line("")

        if days.isEmpty && undatedTasks.isEmpty {
            var empty = AttributedString("No items this week.")
            var emptyStyle = AttributeContainer()
            emptyStyle.font = AppFontStyle.body.uiFont()
            emptyStyle.foregroundColor = .secondary
            empty.setAttributes(emptyStyle)
            out += empty
            out += line("")
        } else {
            // Per-day sections
            for day in days {
                // Day heading
                out += line(f.humanDate.string(from: day.date), style: sec)
                out += line("")

                if day.items.isEmpty {
                    var none = AttributedString("   • No items")
                    let noneStyle = meta
                    // You can also set a secondary color here if you wish
                    none.setAttributes(noneStyle)
                    out += none
                    out += line("") + line("")
                    continue
                }

                // Items (already sorted by groupAgendaByDay: events first, then tasks)
                var eventIndex = 0
                var taskIndex = 0

                for item in day.items {
                    switch item {
                    case .event(let e):
                        eventIndex += 1
                        let (s, eClipped) = clippedTimesForEventOnDay(e, dayStart: day.date)

                        let num = AttributedString("\(eventIndex). ")
                        var t   = AttributedString(
                            eClipped != nil
                            ? f.timeRange(from: s, to: eClipped, includeDay: false)
                            : f.timeRange(from: s, to: nil, includeDay: false)
                        )
                        t.setAttributes(time)

                        let sep = AttributedString(" — ")

                        var title = AttributedString(e.title)
                        title.setAttributes(ttl)

                        out += num + t + sep + title
                        out += line("")

                        // meta line (location, flags)
                        var metaBits: [String] = []
                        if let loc = e.location, !loc.isEmpty { metaBits.append("@ \(loc)") }
                        if e.isRecurring { metaBits.append("recurring") }
                        if e.isOverride  { metaBits.append("override") }
                        if !metaBits.isEmpty {
                            var m = AttributedString("   • " + metaBits.joined(separator: "  • "))
                            m.setAttributes(meta)
                            out += m
                            out += line("")
                        }

                        out += line("") // spacing

                    case .task(let tsk):
                        taskIndex += 1
                        let num = AttributedString("\(taskIndex). ")

                        var pri = AttributedString("(\(tsk.priority)) ")
                        pri.setAttributes(time)

                        var title = AttributedString(tsk.title)
                        title.setAttributes(ttl)

                        // For a week/day section, show due time if present on this date
                        var dueLine: AttributedString?
                        if let due = tsk.dueDate {
                            let dueStrTime = f.humanTime.string(from: due)
                            var dueAttr = AttributedString("   • due \(dueStrTime)")
                            dueAttr.setAttributes(meta)
                            dueLine = dueAttr
                        }

                        out += num + pri + title
                        out += line("")
                        if let dueLine {
                            out += dueLine
                            out += line("")
                        }
                        out += line("") // spacing
                    }
                }
            }

            // Undated tasks at the end
            if !undatedTasks.isEmpty {
                out += line("No due date", style: sec)
                out += line("")
                for (i, tsk) in undatedTasks.enumerated() {
                    let idx = i + 1
                    let num = AttributedString("\(idx). ")

                    var pri = AttributedString("(\(tsk.priority)) ")
                    pri.setAttributes(time)

                    var title = AttributedString(tsk.title)
                    title.setAttributes(ttl)

                    out += num + pri + title
                    out += line("") + line("")
                }
            }
        }

        // (Optional) Plain text fallback
        let textFallback = String(out.characters)

        // ---- Build JSON payload (same shape as renderParts)
        struct Payload: Encodable {
            let schema: String
            let timezone: String
            let start: String
            let end: String
            let items: [AgendaItem]
        }
        let utcISO = ISO8601DateFormatter()
        utcISO.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        utcISO.timeZone = TimeZone(secondsFromGMT: 0)

        let payload = Payload(
            schema: schema,
            timezone: calendar.timeZone.identifier,
            start: utcISO.string(from: agenda.start),
            end: utcISO.string(from: agenda.end),
            items: agenda.items
        )

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .custom { (date, encoder) in
            var c = encoder.singleValueContainer()
            try c.encode(utcISO.string(from: date))
        }
        let jsonOut = (try? String(data: enc.encode(payload), encoding: .utf8)) ?? "{}"

        return AgendaRenderParts(attributed: out, text: textFallback, json: jsonOut, schema: schema)
    }

    // MARK: helpers

    private struct Formatters {
        let timeZone: TimeZone
        let humanDate: DateFormatter
        let humanDateTime: DateFormatter
        let humanTime: DateFormatter

        init(timeZone: TimeZone) {
            self.timeZone = timeZone
            let d1 = DateFormatter()
            d1.timeZone = timeZone
            d1.locale = .autoupdatingCurrent
            d1.dateFormat = "EEE, MMM d yyyy HH:mm"
            humanDateTime = d1

            let d2 = DateFormatter()
            d2.timeZone = timeZone
            d2.locale = .autoupdatingCurrent
            d2.dateFormat = "HH:mm"
            humanTime = d2
            
            let d3 = DateFormatter()
            d3.timeZone = timeZone
            d3.locale = .autoupdatingCurrent
            d3.dateFormat = "EEE, MMM d yyyy"
            humanDate = d3
        }

        func timeRange(from start: Date, to end: Date?, includeDay: Bool = false) -> String {
            if let end {
                return "\(humanTime.string(from: start))–\(humanTime.string(from: end))"
            } else if includeDay {
                return humanDateTime.string(from: start)
            } else {
                return humanTime.string(from: start)
            }
        }
    }
}

extension AgendaRenderer {

    // Optional: a shaped result that’s easy to render in a per-day list
    public struct DayAgenda: Codable {
        public var date: Date          // midnight at start of day in the agenda timezone
        public var items: [AgendaItem] // items that belong on this date
    }

    public static func groupAgendaByDay(_ result: GetAgendaResult, calendar: Calendar) -> ([DayAgenda], [AgendaTask]) {
        // Normalize bounds to day edges
        let periodStart = calendar.startOfDay(for: result.start)
        let periodEndExclusive: Date = {
            let endStartOfDay = calendar.startOfDay(for: result.end)
            if endStartOfDay == result.end { return endStartOfDay }
            return calendar.date(byAdding: .day, value: 1, to: endStartOfDay)!
        }()

        // Prebuild days
        var dayKeys: [Date] = []
        var dayCursor = periodStart
        while dayCursor < periodEndExclusive {
            dayKeys.append(dayCursor)
            dayCursor = calendar.date(byAdding: .day, value: 1, to: dayCursor)!
        }

        var buckets: [Date: [AgendaItem]] = Dictionary(uniqueKeysWithValues: dayKeys.map { ($0, []) })
        var undatedTasks: [AgendaTask] = []

        func bucketDate(for date: Date) -> Date {
            calendar.startOfDay(for: date)
        }

        func eachDayKeys(from a: Date, toExclusive b: Date) -> [Date] {
            guard a < b else { return [] }
            var d = calendar.startOfDay(for: a)
            let endKeyExclusive = calendar.startOfDay(for: b)
            var keys: [Date] = []
            while d <= endKeyExclusive {
                if d == endKeyExclusive {
                    if d < b { keys.append(d) }
                    break
                } else {
                    keys.append(d)
                    d = calendar.date(byAdding: .day, value: 1, to: d)!
                }
            }
            return keys
        }

        func clippedRange(start a: Date, end bOpt: Date?) -> (Date, Date) {
            let b = bOpt ?? a
            let start = max(a, periodStart)
            let endExclusive = min(bOpt ?? b, periodEndExclusive)
            if start >= endExclusive {
                let fallbackEnd = calendar.date(byAdding: .second, value: 1, to: start) ?? start
                return (start, fallbackEnd)
            }
            return (start, endExclusive)
        }

        for item in result.items {
            switch item {
            case .event(let ev):
                let (s, eExclusive) = clippedRange(start: ev.start, end: ev.end)
                for day in eachDayKeys(from: s, toExclusive: eExclusive) where buckets[day] != nil {
                    buckets[day]!.append(item)
                }

            case .task(let task):
                if let due = task.dueDate {
                    let key = bucketDate(for: due)
                    if key >= periodStart && key < periodEndExclusive, buckets[key] != nil {
                        buckets[key]!.append(item)
                    }
                } else {
                    undatedTasks.append(task)
                }
            }
        }

        func priorityRank(_ p: String) -> Int {
            switch p.lowercased() {
            case "high": return 0
            case "medium": return 1
            case "low": return 2
            default: return 3
            }
        }

        func sortDayItems(_ items: inout [AgendaItem]) {
            items.sort { a, b in
                switch (a, b) {
                case (.event(let e1), .event(let e2)):
                    if e1.start != e2.start { return e1.start < e2.start }
                    return e1.title.localizedCaseInsensitiveCompare(e2.title) == .orderedAscending

                case (.event, .task):
                    return true
                case (.task, .event):
                    return false

                case (.task(let t1), .task(let t2)):
                    let r1 = priorityRank(t1.priority), r2 = priorityRank(t2.priority)
                    if r1 != r2 { return r1 < r2 }
                    if t1.title.caseInsensitiveCompare(t2.title) != .orderedSame {
                        return t1.title.localizedCaseInsensitiveCompare(t2.title) == .orderedAscending
                    }
                    if let d1 = t1.dueDate, let d2 = t2.dueDate, d1 != d2 { return d1 < d2 }
                    return t1.id.uuidString < t2.id.uuidString
                }
            }
        }

        var dayAgendas: [DayAgenda] = []
        for day in dayKeys {
            var items = buckets[day] ?? []
            sortDayItems(&items)
            dayAgendas.append(DayAgenda(date: day, items: items))
        }

        return (dayAgendas, undatedTasks)
    }
}
