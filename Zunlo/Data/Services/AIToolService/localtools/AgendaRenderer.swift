//
//  AgendaRenderer.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/20/25.
//

import Foundation

// MARK: - Agenda Rendering

// MARK: - Split agenda output into text + json

public struct AgendaRenderParts {
    public let attributed: AttributedString
    public let text: String
    public let json: String
    public let schema: String
}

public enum AgendaRenderMode {
    case textOnly
    case jsonOnly
    case parts // default
}

public struct AgendaRenderer {
    public static func renderParts(
        _ agenda: GetAgendaResult,
        agendaRange: GetAgendaArgs.DateRange,
        schema: String = "zunlo.agenda#1"
    ) -> AgendaRenderParts {
        let tz = TimeZone(identifier: agenda.timezone) ?? .current
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
        var hdr  = AttributeContainer(); hdr.font  = .system(.title3, design: .rounded).weight(.semibold)
        var sec  = AttributeContainer(); sec.font  = .system(.headline, design: .rounded)
        var time = AttributeContainer(); time.font = .system(.subheadline); time.foregroundColor = .secondary
        var ttl  = AttributeContainer(); ttl.font  = .system(.body).weight(.semibold)
        var meta = AttributeContainer(); meta.font = .system(.footnote);   meta.foregroundColor = .secondary

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

                var due = AttributedString(" — due \(dueStr)")
                due.setAttributes(time)

                out += num + pri + title + due
                out += line("")
            }
        }

        if events.isEmpty && tasks.isEmpty {
            var empty = AttributedString("No items in this range.")
            var emptyStyle = AttributeContainer(); emptyStyle.font = .system(.body); emptyStyle.foregroundColor = .secondary
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
