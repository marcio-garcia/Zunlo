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
    public static func renderParts(_ agenda: GetAgendaResult,
                                   schema: String = "zunlo.agenda#1") -> AgendaRenderParts {
        let tz = TimeZone(identifier: agenda.timezone) ?? .current
        let f = Formatters(timeZone: tz)

        // ---- Build TEXT (same formatting you already liked) ----
        let events: [AgendaEvent] = agenda.items.compactMap { if case let .event(e) = $0 { e } else { nil } }
            .sorted { $0.start < $1.start }
        let tasks: [AgendaTask] = agenda.items.compactMap { if case let .task(t) = $0 { t } else { nil } }
            .sorted { (l, r) in
                switch (l.dueDate, r.dueDate) {
                case let (a?, b?): return a < b
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return l.title.localizedCaseInsensitiveCompare(r.title) == .orderedAscending
                }
            }

        var textSections: [String] = []
        textSections.append("# Agenda — \(f.humanDateTime.string(from: agenda.start)) → \(f.humanDateTime.string(from: agenda.end))\n_Timezone: \(tz.identifier)_\n")

        if !events.isEmpty {
            var lines = ["## Events"]
            for (i, e) in events.enumerated() {
                let idx = i + 1
                let timeRange = f.timeRange(from: e.start, to: e.end)
                var meta: [String] = []
                if let loc = e.location, !loc.isEmpty { meta.append("@ \(loc)") }
                if let color = e.color, !color.isEmpty { meta.append("{color: \(color)}") }
                var flags: [String] = []
                if e.isRecurring { flags.append("recurring") }
                if e.isOverride { flags.append("override") }
                if !flags.isEmpty { meta.append("[\(flags.joined(separator: ", "))]") }

                lines.append("\(idx). \(timeRange) — **\(e.title)**  _(id: \(shortID(e.id)))_")
                if !meta.isEmpty { lines.append("   • " + meta.joined(separator: "  • ")) }
            }
            lines.append("")
            textSections.append(lines.joined(separator: "\n"))
        }

        if !tasks.isEmpty {
            var lines = ["## Tasks"]
            for (i, t) in tasks.enumerated() {
                let idx = i + 1
                let dueStr = t.dueDate.map { f.humanDateTime.string(from: $0) } ?? "no due date"
                let tagsStr = t.tags.isEmpty ? "" : "  • tags: " + t.tags.map { "#\($0)" }.joined(separator: " ")
                lines.append("\(idx). (\(t.priority)) **\(t.title)** — due \(dueStr)  _(id: \(shortID(t.id)))_\(tagsStr)")
            }
            lines.append("")
            textSections.append(lines.joined(separator: "\n"))
        }

        if events.isEmpty && tasks.isEmpty {
            textSections.append("_No items in this range._\n")
        }

        let textOut = textSections.joined(separator: "\n")

        // ---- Build JSON (machine-readable) ----
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

        return AgendaRenderParts(text: textOut, json: jsonOut, schema: schema)
    }

    // MARK: helpers

    private static func shortID(_ id: UUID) -> String {
        id.uuidString.lowercased().split(separator: "-").first.map(String.init) ?? id.uuidString
    }

    private struct Formatters {
        let timeZone: TimeZone
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
        }

        func timeRange(from start: Date, to end: Date?) -> String {
            if let end {
                return "\(humanTime.string(from: start))–\(humanTime.string(from: end))"
            } else {
                return humanDateTime.string(from: start)
            }
        }
    }
}
