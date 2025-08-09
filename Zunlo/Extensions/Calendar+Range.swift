//
//  Calendar+Range.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

extension Calendar {
    func dayRange(containing date: Date) -> Range<Date> {
        let start = startOfDay(for: date)
        let end = self.date(byAdding: DateComponents(day: 1, second: -1), to: start)!
        return start..<end
    }
}
