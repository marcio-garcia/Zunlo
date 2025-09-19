//
//  DateComponents+Compare.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/18/25.
//

import Foundation

extension DateComponents {
    
    /// Checks if this DateComponents represents the same day as another DateComponents
    /// - Parameters:
    ///   - other: The other DateComponents to compare with
    ///   - includeHour: Whether to also check if the hour matches (optional, default: false)
    ///   - includeMinute: Whether to also check if the minute matches (optional, default: false)
    /// - Returns: True if they represent the same day (and optionally same hour/minute)
    func isSameDay(as other: DateComponents, includeHour: Bool = false, includeMinute: Bool = false) -> Bool {
        // Check year, month, and day
        guard self.year == other.year,
              self.month == other.month,
              self.day == other.day else {
            return false
        }
        
        // Check hour if requested
        if includeHour {
            guard self.hour == other.hour else {
                return false
            }
        }
        
        // Check minute if requested
        if includeMinute {
            guard self.minute == other.minute else {
                return false
            }
        }
        
        return true
    }
    
    /// Checks if this DateComponents represents the same day as another DateComponents
    /// - Parameters:
    ///   - other: The other DateComponents to compare with
    ///   - precision: The level of precision for comparison
    /// - Returns: True if they match at the specified precision level
    func isSame(as other: DateComponents, precision: DatePrecision) -> Bool {
        switch precision {
        case .day:
            return isSameDay(as: other)
        case .hour:
            return isSameDay(as: other, includeHour: true)
        case .minute:
            return isSameDay(as: other, includeHour: true, includeMinute: true)
        case .second:
            return isSameDay(as: other, includeHour: true, includeMinute: true) && self.second == other.second
        }
    }
    
    /// Alternative method that takes optional parameters as a single options set
    /// - Parameters:
    ///   - other: The other DateComponents to compare with
    ///   - options: Set of components to include in comparison
    /// - Returns: True if all specified components match
    func isSame(as other: DateComponents, comparing options: Set<Calendar.Component>) -> Bool {
        for component in options {
            switch component {
            case .year:
                guard self.year == other.year else { return false }
            case .month:
                guard self.month == other.month else { return false }
            case .day:
                guard self.day == other.day else { return false }
            case .hour:
                guard self.hour == other.hour else { return false }
            case .minute:
                guard self.minute == other.minute else { return false }
            case .second:
                guard self.second == other.second else { return false }
            default:
                continue // Ignore other components
            }
        }
        return true
    }
}

/// Enum to specify precision level for date comparison
enum DatePrecision {
    case day
    case hour
    case minute
    case second
}
