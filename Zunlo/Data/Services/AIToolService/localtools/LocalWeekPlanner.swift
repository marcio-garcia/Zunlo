//
//  LocalWeekPlanner.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/19/25.
//

import Foundation

final class LocalWeekPlanner: WeekPlanning {
    private let userId: UUID
    private let cal: Calendar
    private let agenda: AgendaComputing
    private let toolRepo: DomainRepositories
    
    init(
        userId: UUID,
        agenda: AgendaComputing,
        toolRepo: DomainRepositories,
        calendar: Calendar = .appDefault
    ) {
        self.userId = userId
        self.agenda = agenda
        self.cal = calendar
        self.toolRepo = toolRepo
    }

    func proposePlan(start: Date, horizonDays: Int, timezone: TimeZone, objectives: [String], constraints: Constraints?) async throws -> ProposedPlan {
        let end = (cal.date(byAdding: .day, value: horizonDays, to: start) ?? start).addingTimeInterval(1)
        let window = start..<end
        let ag = try await agenda.computeAgenda(range: window, timezone: timezone)

        // Busy = events
        let busy = ag.items.compactMap { item -> (Date, Date?, String, UUID?)? in
            if case .event(let e) = item { return (e.start, e.end, e.title, e.id) }
            return nil
        }.sorted { $0.0 < $1.0 }

        // Working hours (defaults)
        var work = constraints?.workHours ?? [:]
        if work.isEmpty {
            // Mon–Fri 09:00–17:00
            for w in 2...6 { work[w] = (DateComponents(hour: 9), DateComponents(hour: 17)) }
        }

        // Free blocks
//        let free = computeFreeBlocks(start: start, end: end, workHours: work, busy: busy, tz: timezone)

        let context = await AIContextBuilder().build(
            userId: userId,
            time: SystemTimeProvider(),
            policyProvider: SuggestionPolicyProvider(),
            tasks: AppState.shared.taskSuggestionEngine!,
            events: AppState.shared.eventSuggestionEngine!,
            weather: WeatherService.shared,
            rangeStart: start,
            rangeEnd: end
        )
        let free = context.freeWindows
        
        // Candidate tasks: due within window or undated; not completed
        let range = start..<end
        let tasks = try await toolRepo.fetchTasks(range: range) // try await  db.fetchCandidateTasks(start: start, end: end)

        // Greedy pack
        let minM = constraints?.minFocusMins ?? 30
        let maxM = constraints?.maxFocusMins ?? 120
        var blocks: [ProposedBlock] = busy.map { .init(kind: .meeting, start: $0.0, end: $0.1, title: $0.2, taskId: nil, eventId: $0.3) }

        var queue = tasks // already sorted by priority desc, due asc
        for slot in free {
            var cursor = slot.start
            while cursor < slot.end, let task = queue.first {
                let chunk = min(TimeInterval(maxM*60), slot.end.timeIntervalSince(cursor))
                if chunk < TimeInterval(minM*60) { break }
                let block = ProposedBlock(kind: .focus, start: cursor, end: cursor.addingTimeInterval(chunk), title: "Focus: \(task.title)", taskId: task.id, eventId: nil)
                blocks.append(block)
                cursor = block.end ?? Date()
                // rotate queue (or decrement remaining est if you add it later)
                _ = queue.removeFirst()
            }
        }

        blocks.sort { $0.start < $1.start }
        let notes = [
            "Planned \(blocks.filter{ $0.kind == .focus }.count) focus blocks.",
            "Busy: \(busy.count) meetings/events considered.",
            "Objectives: \(objectives.prefix(3).joined(separator: "; "))."
        ]
        return ProposedPlan(start: start, end: end, blocks: blocks, notes: notes)
    }

//    private func computeFreeBlocks(start: Date, end: Date, workHours: [Int:(start: DateComponents, end: DateComponents)], busy: [(Date,Date?,String,UUID?)], tz: TimeZone) -> [DateInterval] {
//        var results: [DateInterval] = []
//        var day = cal.startOfDay(for: start)
//        while day < end {
//            let weekday = cal.component(.weekday, from: day) // 1=Sun..7=Sat
//            if let span = workHours[weekday],
//               let ws = cal.date(bySettingHour: span.start.hour ?? 9, minute: span.start.minute ?? 0, second: 0, of: day),
//               let we = cal.date(bySettingHour: span.end.hour ?? 17, minute: span.end.minute ?? 0, second: 0, of: day) {
//                var freeSegs = [DateInterval(start: ws, end: we)]
//                for (bs, be, _, _) in busy where bs < we && (be == nil || be! > ws) {
//                    freeSegs = freeSegs.flatMap { seg -> [DateInterval] in
//                        if be <= seg.start || bs >= seg.end { return [seg] }
//                        var parts: [DateInterval] = []
//                        if bs > seg.start { parts.append(DateInterval(start: seg.start, end: bs)) }
//                        if be < seg.end { parts.append(DateInterval(start: be, end: seg.end)) }
//                        return parts
//                    }
//                }
//                results.append(contentsOf: freeSegs.filter { $0.duration > 60 }) // >1min
//            }
//            day = cal.date(byAdding: .day, value: 1, to: day) ?? end
//        }
//        return results
//    }
}
