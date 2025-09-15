//
//  Date+DateComponents.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/14/25.
//

import Foundation

extension Date {
    func components(calendar: Calendar = .appDefault) -> DateComponents {
        return calendar.dateComponents([.year,.month,.day,.hour,.minute,.weekday], from: self)
    }
}
