//
//  Array+TimeWindow.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

import Foundation

public extension Array where Element == TimeWindow {
    /// First free window strictly after `date`.
    func firstAfter(_ date: Date) -> TimeWindow? {
        first { $0.start > date }
    }
}
