//
//  DateInterval+Range.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation

extension DateInterval {
    func toDateRange() -> Range<Date> {
        let exclusiveEnd = Calendar.current.date(byAdding: .second, value: 1, to: self.end) ?? self.end
        return self.start..<exclusiveEnd
    }
}
