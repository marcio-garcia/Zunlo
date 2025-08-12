//
//  Date.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

import Foundation

enum DT {
    static let tz = TimeZone(secondsFromGMT: 0)! // deterministic tests
    static var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }()
    static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
    static func d(_ s: String) -> Date { fmt.date(from: s)! }
}

extension Calendar {
    func dayRange(containing date: Date) -> Range<Date> {
        let start = startOfDay(for: date)
        let end = self.date(byAdding: .day, value: 1, to: start)!
        return start..<end
    }
}
