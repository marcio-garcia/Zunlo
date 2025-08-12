//
//  TaskScorer.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

import Foundation

/// Score tasks using priority and due-date proximity, with deterministic tie-breaks.
public struct TaskScorer {
    static func score(_ task: UserTask, now: Date) -> Int {
        // Base from priority
        var s = task.priority.weight * 1000

        // Due-date proximity: sooner due → higher score
        if let due = task.dueDate {
            // hours until due (negative if overdue)
            let hours = Int(due.timeIntervalSince(now) / 3600)
            // Overdue gets a big boost; near-term due gets a smaller boost.
            if hours <= 0 {
                s += 600 + max(-hours, 0) // more overdue → slightly higher
            } else if hours <= 24 {
                s += 400 - min(hours, 24) // earlier within a day
            } else if hours <= 72 {
                s += 300 - (hours - 24)   // within three days
            } else {
                s += 200                  // later due still contributes
            }
        } else {
            s += 100 // no due date: small baseline
        }

        // Age bias: older tasks get a nudge (prevents perpetual starvation)
        let ageHours = max(0, Int(Date().timeIntervalSince(task.createdAt) / 3600))
        s += min(ageHours, 48) // cap the nudge

        return s
    }

    /// Returns tasks sorted best-first.
    static func rank(_ tasks: [UserTask], now: Date) -> [UserTask] {
        tasks
            .filter { $0.isActionable }
            .sorted {
                let s0 = score($0, now: now), s1 = score($1, now: now)
                if s0 != s1 { return s0 > s1 }
                // Ties: earlier due first, then newer update first, then title
                switch ($0.dueDate, $1.dueDate) {
                case let (d0?, d1?) where d0 != d1: return d0 < d1
                case (nil, .some): return false
                case (.some, nil): return true
                default:
                    if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
            }
    }
}
