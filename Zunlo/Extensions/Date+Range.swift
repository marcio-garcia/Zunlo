//
//  Date+Range.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

extension Date {
    static func clamp(_ value: Date, to range: Range<Date>) -> Date {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
